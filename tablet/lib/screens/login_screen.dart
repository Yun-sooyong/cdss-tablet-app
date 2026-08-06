import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared/theme/theme.dart';
import 'package:tablet/providers/auth_provider.dart';
import 'package:tablet/widgets/account_request_dialog.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idController = useTextEditingController();
    final pwController = useTextEditingController();
    final obscure = useState(true);
    final busy = useState(false);
    final error = useState<String?>(null);

    Future<void> submit() async {
      if (busy.value) return;
      busy.value = true;
      error.value = null;

      try {
        await ref
            .read(authProvider.notifier)
            .login(idController.text.trim(), pwController.text);
      } on DioException catch (e) {
        error.value = switch (e.response?.statusCode) {
          401 => '아이디 또는 비밀번호가 올바르지 않습니다.',
          400 => '입력값을 확인해 주세요.',
          _ =>
            e.type == DioExceptionType.connectionTimeout ||
                    e.type == DioExceptionType.receiveTimeout
                ? '서버 응답이 없습니다. 네트워크를 확인해 주세요.'
                : '로그인에 실패했습니다.',
        };
      } catch (_) {
        error.value = '로그인에 실패했습니다.';
      }finally {
        if (context.mounted) busy.value = false;
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              // 화면 좌우분할
              child: Row(
                children: [
                  // 왼쪽 이미지
                  Expanded(child: Image.asset('assets/icons1.png')),
                  const SizedBox(width: AppDimens.gapXl),
                  // 오른쪽 로그인용 textfield
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'V-Tree',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontSize: 28),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '건강을 더 가까이',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppDimens.gapXxl),
                        TextField(
                          controller: idController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: '아이디',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: AppDimens.gapLg),
                        TextField(
                          controller: pwController,
                          obscureText: obscure.value,
                          onSubmitted: (_) => submit(),
                          decoration: InputDecoration(
                            labelText: '비밀번호',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscure.value
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () => obscure.value = !obscure.value,
                            ),
                          ),
                        ),
                        if (error.value != null) ...[
                          const SizedBox(height: AppDimens.gapMd),
                          Text(
                            error.value!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppDimens.gapXl),
                        FilledButton(
                          onPressed: busy.value ? null : submit,
                          child: busy.value
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('로그인'),
                        ),
                        const SizedBox(height: AppDimens.gapXl),
                        // 모바일 디자인의 '또는' 구분선 패턴
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimens.gapMd,
                              ),
                              child: Text(
                                '또는',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: AppDimens.gapXl),
                        OutlinedButton(
                          onPressed: busy.value
                              ? null
                              : () => showAccountRequestDialog(context, ref),
                          child: const Text('신규 계정 신청'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
