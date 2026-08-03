import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../router/routes.dart';

class UploadScreen extends HookConsumerWidget {
  const UploadScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(child: Text('업로드')),
    );
  }
}
