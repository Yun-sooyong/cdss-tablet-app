import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
<<<<<<< HEAD
import 'main_shell.dart';
import 'signup_screen.dart';
=======
import '../utils/validators.dart';
import 'main_shell.dart';
import 'signup_screen.dart';
import '../widgets/loading_spinner.dart';
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d

class LoginScreen extends StatefulWidget {
  final AuthService authService;

  const LoginScreen({super.key, required this.authService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
<<<<<<< HEAD
=======
  final _formKey = GlobalKey<FormState>();
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _goToShell() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
<<<<<<< HEAD
      MaterialPageRoute(
        builder: (_) => MainShell(authService: widget.authService),
      ),
=======
      MaterialPageRoute(builder: (_) => MainShell(authService: widget.authService)),
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
    );
  }

  Future<void> _handleEmailLogin() async {
<<<<<<< HEAD
=======
    if (!_formKey.currentState!.validate()) return;
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
<<<<<<< HEAD
      await widget.authService.loginWithEmail(
        _emailController.text,
        _passwordController.text,
      );
=======
      await widget.authService.loginWithEmail(_emailController.text, _passwordController.text);
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
      await _goToShell();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSocialLogin(String provider) async {
    setState(() => _isLoading = true);
    try {
      await widget.authService.loginWithSocial(provider);
      await _goToShell();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
<<<<<<< HEAD
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/tree_logo.png', height: 140),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: '이메일',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: '비밀번호',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isLoading ? null : _handleEmailLogin,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('로그인'),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('또는', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: AppColors.primary, width: 1.2),
                      foregroundColor: Colors.black87,
                    ),
                    icon: const Icon(Icons.g_mobiledata),
                    label: const Text('구글로 계속하기'),
                    onPressed:
                        _isLoading ? null : () => _handleSocialLogin('google'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: AppColors.primary, width: 1.2),
                      foregroundColor: Colors.black87,
                    ),
                    icon: const Icon(Icons.chat_bubble),
                    label: const Text('카카오로 계속하기'),
                    onPressed:
                        _isLoading ? null : () => _handleSocialLogin('kakao'),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SignupScreen(authService: widget.authService),
                    ),
                  ),
                  child: const Text('회원가입'),
                ),
              ],
=======
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/tree_logo.png', height: 96),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                    decoration: const InputDecoration(hintText: '이메일', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    validator: Validators.loginPassword,
                    decoration: const InputDecoration(hintText: '비밀번호', border: OutlineInputBorder()),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                      onPressed: _isLoading ? null : _handleEmailLogin,
                      child: _isLoading
                          ? const LoadingSpinner(size: 20)
                          : const Text('로그인'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('또는', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary, width: 1.2),
                        foregroundColor: Colors.black87,
                      ),
                      icon: const Icon(Icons.g_mobiledata),
                      label: const Text('구글로 계속하기'),
                      onPressed: _isLoading ? null : () => _handleSocialLogin('google'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary, width: 1.2),
                        foregroundColor: Colors.black87,
                      ),
                      icon: const Icon(Icons.chat_bubble),
                      label: const Text('카카오로 계속하기'),
                      onPressed: _isLoading ? null : () => _handleSocialLogin('kakao'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SignupScreen(authService: widget.authService)),
                    ),
                    child: const Text('회원가입'),
                  ),
                ],
              ),
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
            ),
          ),
        ),
      ),
    );
  }
<<<<<<< HEAD
}
=======
}
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
