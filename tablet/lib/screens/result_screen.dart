import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../router/routes.dart';

class ResultScreen extends HookConsumerWidget {
  const ResultScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('결과'),
          const SizedBox(height: 16),
          FilledButton(
            // 상세는 go가 아니라 push — 뒤로가기가 필요하다
            onPressed: () => context.push(Routes.resultDetail),
            child: const Text('상세 열기'),
          ),
        ],
      ),
    );
  }
}
