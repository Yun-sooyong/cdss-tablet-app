import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared/theme/theme.dart';
import 'package:tablet/models/models.dart';
import 'package:tablet/providers/batch_provider.dart';

/// 환자 QR을 스캔해 신원을 확인한다.
///
/// 환자 앱이 만든 토큰은 **일회성이고 5분이면 만료**된다
/// (`POST /patients/me/qr/`). 태블릿은 검증만 한다.
class QrScreen extends HookConsumerWidget {
  const QrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = useMemoized(MobileScannerController.new);
    useEffect(() => controller.dispose, [controller]);

    final busy = useState(false);
    final result = useState<PatientSummary?>(null);
    final error = useState<String?>(null);
    // 카메라가 같은 코드를 연속으로 물어오므로 한 번 처리한 토큰은 무시한다
    final handled = useRef<String?>(null);

    Future<void> verify(String token) async {
      if (busy.value || handled.value == token) return;
      handled.value = token;
      busy.value = true;
      error.value = null;
      try {
        final p = await ref.read(patientRepositoryProvider).verifyQr(token);
        result.value = p;
        if (p == null) {
          error.value = '유효한 QR이지만 서버가 환자 정보를 주지 않았습니다.';
        }
      } on DioException catch (e) {
        result.value = null;
        error.value = switch (e.response?.statusCode) {
          404 => '유효하지 않거나 이미 사용된 QR입니다.',
          400 => '만료된 QR입니다. 환자에게 다시 생성을 요청하세요.',
          403 => '권한이 없습니다.',
          _ => 'QR 확인에 실패했습니다: ${e.message}',
        };
      } catch (e) {
        result.value = null;
        error.value = 'QR 확인에 실패했습니다: $e';
      } finally {
        busy.value = false;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(AppDimens.gapXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('QR 환자 확인', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppDimens.gapSm),
          Text(
            '환자 앱에서 만든 QR을 비춰 주세요. 일회성이고 5분이면 만료됩니다.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppDimens.gapLg),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Scanner(
                    controller: controller,
                    onToken: verify,
                    busy: busy.value,
                  ),
                ),
                const SizedBox(width: AppDimens.gapXl),
                Expanded(
                  child: _Result(
                    patient: result.value,
                    error: error.value,
                    onReset: () {
                      handled.value = null;
                      result.value = null;
                      error.value = null;
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Scanner extends StatelessWidget {
  const _Scanner({
    required this.controller,
    required this.onToken,
    required this.busy,
  });

  final MobileScannerController controller;
  final ValueChanged<String> onToken;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(AppDimens.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              for (final b in capture.barcodes) {
                final v = b.rawValue;
                if (v != null && v.isNotEmpty) {
                  onToken(v);
                  break;
                }
              }
            },
            errorBuilder: (context, error) => _CameraError(error: error),
          ),
          if (busy)
            ColoredBox(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});
  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 에뮬레이터에는 카메라가 없어 여기로 온다
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.gapXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.no_photography_outlined,
                size: 40, color: theme.disabledColor),
            const SizedBox(height: AppDimens.gapMd),
            Text(
              '카메라를 사용할 수 없습니다',
              style: TextStyle(color: theme.disabledColor),
            ),
            const SizedBox(height: 4),
            Text(
              error.errorCode.name,
              style: TextStyle(color: theme.disabledColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.patient,
    required this.error,
    required this.onReset,
  });

  final PatientSummary? patient;
  final String? error;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final p = patient;

    return Container(
      padding: const EdgeInsets.all(AppDimens.gapXl),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(AppDimens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('확인 결과', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppDimens.gapLg),
          if (error != null) ...[
            Row(
              children: [
                Icon(Icons.error_outline, color: cs.error),
                const SizedBox(width: AppDimens.gapSm),
                Expanded(
                  child: Text(error!, style: TextStyle(color: cs.error)),
                ),
              ],
            ),
          ] else if (p == null) ...[
            Text(
              'QR을 비추면 여기에 환자 정보가 표시됩니다.',
              style: TextStyle(color: theme.disabledColor),
            ),
          ] else ...[
            Row(
              children: [
                Icon(Icons.verified_user_outlined, color: cs.primary),
                const SizedBox(width: AppDimens.gapSm),
                Text('확인됨', style: TextStyle(color: cs.primary)),
              ],
            ),
            const SizedBox(height: AppDimens.gapLg),
            _Field('이름', p.name),
            _Field('차트번호', p.chartNumber),
            if (p.birthDate != null)
              _Field(
                '생년월일',
                '${p.birthDate!.year}-'
                    '${p.birthDate!.month.toString().padLeft(2, '0')}-'
                    '${p.birthDate!.day.toString().padLeft(2, '0')}',
              ),
            if (p.sex != null) _Field('성별', _sexLabel(p.sex!)),
          ],
          const Spacer(),
          if (patient != null || error != null)
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 스캔'),
              ),
            ),
        ],
      ),
    );
  }

  static String _sexLabel(String s) => switch (s) {
    'M' => '남',
    'F' => '여',
    'O' => '기타',
    _ => '미상',
  };
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
