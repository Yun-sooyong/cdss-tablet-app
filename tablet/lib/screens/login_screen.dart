import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailTextController = useTextEditingController();
    final pwTextController = useTextEditingController();
    final isPWsecret = useState(true);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              Expanded(child: Center(child: Image.asset('assets/icons1.png'))),
              // Textfield
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 이메일 입력창
                    TextField(
                      controller: emailTextController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: '이메일',
                        hintText: 'example@email.com',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 비밀번호 입력창
                    TextField(
                      controller: pwTextController,
                      obscureText: isPWsecret.value, // 비밀번호 숨김 여부 적용
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        prefixIcon: const Icon(Icons.lock_outlined),
                        // 비밀번호 보이기/숨기기 토글 버튼
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPWsecret.value
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            isPWsecret.value = !isPWsecret.value;
                          },
                        ),
                      ),
                    ),
                    ElevatedButton(
                      child: Text('로그인 하기'),
                      onPressed: () {
                        // TODO : isLogin = true 변경, 로그인 검증
                        // isLogin = true 로 변경
                      },
                    ),
                    ElevatedButton(child: Text('아이디 발급 요청'), onPressed: () {
                      // TODO : 아이디 발급 요청 / 발급 시퀀스 진행
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
