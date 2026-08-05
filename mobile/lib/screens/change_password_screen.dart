import 'package:flutter/material.dart';
import '../services/auth_service.dart';
<<<<<<< HEAD
=======
import '../widgets/loading_spinner.dart';
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d

class ChangePasswordScreen extends StatefulWidget {
  final AuthService authService;

  const ChangePasswordScreen({super.key, required this.authService});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSaving = false;
  String? _error;

  Future<void> _save() async {
    if (_newController.text != _confirmController.text) {
      setState(() => _error = '새 비밀번호가 서로 일치하지 않아요');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.authService.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 변경되었습니다.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('비밀번호 변경')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _currentController,
              obscureText: true,
<<<<<<< HEAD
              decoration: const InputDecoration(
                  labelText: '현재 비밀번호', border: OutlineInputBorder()),
=======
              decoration: const InputDecoration(labelText: '현재 비밀번호', border: OutlineInputBorder()),
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newController,
              obscureText: true,
<<<<<<< HEAD
              decoration: const InputDecoration(
                  labelText: '새 비밀번호', border: OutlineInputBorder()),
=======
              decoration: const InputDecoration(labelText: '새 비밀번호', border: OutlineInputBorder()),
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: true,
<<<<<<< HEAD
              decoration: const InputDecoration(
                  labelText: '새 비밀번호 확인', border: OutlineInputBorder()),
=======
              decoration: const InputDecoration(labelText: '새 비밀번호 확인', border: OutlineInputBorder()),
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
<<<<<<< HEAD
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
=======
                    ? const LoadingSpinner(size: 20)
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
                    : const Text('변경하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
<<<<<<< HEAD
}
=======
}
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
