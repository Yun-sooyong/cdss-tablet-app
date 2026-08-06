import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared/theme/theme.dart';
import 'package:tablet/api/api.dart';
import 'package:tablet/models/models.dart';

/// 신규 계정 발급 신청. 로그인 화면에서 연다.
///
/// 초대코드 방식(`/auth/invitations/redeem/`)은 서버에서 삭제됐다.
/// 지금은 신청 → 관리자 승인 → 관리자가 임시 비밀번호 전달 순서다.
Future<void> showAccountRequestDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _AccountRequestDialog(),
  );
}

class _AccountRequestDialog extends HookConsumerWidget {
  const _AccountRequestDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = useTextEditingController();
    final email = useTextEditingController();
    final department = useTextEditingController();
    final note = useTextEditingController();
    final role = useState(StaffRole.doctor);

    final busy = useState(false);
    final error = useState<String?>(null);
    final done = useState(false);

    final theme = Theme.of(context);

    Future<void> submit() async {
      if (busy.value) return;
      if (name.text.trim().isEmpty || email.text.trim().isEmpty) {
        error.value = '이름과 이메일은 필수입니다.';
        return;
      }
      busy.value = true;
      error.value = null;
      try {
        await ref.read(authApiProvider).requestAccount(
          name: name.text.trim(),
          email: email.text.trim(),
          role: role.value.raw,
          department: department.text.trim(),
          note: note.text.trim(),
        );
        done.value = true;
      } on DioException catch (e) {
        final data = e.response?.data;
        error.value = switch (e.response?.statusCode) {
          // 같은 이메일로 대기 중인 신청이 있으면 서버가 막는다
          400 => _firstMessage(data) ?? '입력값을 확인해 주세요.',
          409 => '이미 대기 중인 신청이 있습니다.',
          _ => '신청에 실패했습니다. 네트워크를 확인해 주세요.',
        };
      } catch (_) {
        error.value = '신청에 실패했습니다.';
      } finally {
        busy.value = false;
      }
    }

    if (done.value) {
      return AlertDialog(
        title: const Text('신청이 접수됐습니다'),
        content: const SizedBox(
          width: 420,
          child: Text(
            '관리자가 승인하면 계정이 만들어지고, 임시 비밀번호를 별도로 전달받게 됩니다.\n'
            '아이디와 비밀번호는 신청자가 정하지 않습니다.',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('신규 계정 신청'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '이름 *'),
              ),
              const SizedBox(height: AppDimens.gapMd),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '이메일 *'),
              ),
              const SizedBox(height: AppDimens.gapLg),
              Text('직군 *', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: AppDimens.gapSm),
              SegmentedButton<StaffRole>(
                segments: [
                  for (final r in StaffRole.values)
                    ButtonSegment(value: r, label: Text(r.label)),
                ],
                selected: {role.value},
                onSelectionChanged: (s) => role.value = s.first,
              ),
              const SizedBox(height: AppDimens.gapLg),
              TextField(
                controller: department,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '부서',
                  hintText: '예: 병리과',
                ),
              ),
              const SizedBox(height: AppDimens.gapMd),
              TextField(
                controller: note,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '신청 사유',
                  alignLabelWithHint: true,
                ),
              ),
              if (error.value != null) ...[
                const SizedBox(height: AppDimens.gapMd),
                Text(
                  error.value!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy.value ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: busy.value ? null : submit,
          child: busy.value
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('신청'),
        ),
      ],
    );
  }

  /// DRF는 `{"email": ["이미 ..."], ...}` 모양으로 준다. 첫 메시지만 뽑는다.
  static String? _firstMessage(Object? data) {
    if (data is Map) {
      for (final v in data.values) {
        if (v is List && v.isNotEmpty) return '${v.first}';
        if (v is String) return v;
      }
    }
    return null;
  }
}
