import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import 'main_shell.dart';
import '../widgets/loading_spinner.dart';

class SignupScreen extends StatefulWidget {
  final AuthService authService;

  const SignupScreen({super.key, required this.authService});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime? _birthDate;
  Sex? _sex;
  bool _isLoading = false;
  String? _error;

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _birthDate = picked);
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate == null) {
      setState(() => _error = '생년월일을 선택해줘');
      return;
    }
    if (_sex == null) {
      setState(() => _error = '성별을 선택해줘');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await widget.authService.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        name: _nameController.text,
        birthDate: _birthDate!,
        sex: _sex!,
        address: _addressController.text,
        phone: _phoneController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainShell(authService: widget.authService),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  validator: (v) => Validators.required(v, '이름'),
                  decoration: const InputDecoration(
                    hintText: '이름',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                  decoration: const InputDecoration(
                    hintText: '이메일',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  validator: Validators.password,
                  decoration: const InputDecoration(
                    hintText: '비밀번호 (8자 이상)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _pickBirthDate,
                  child: Text(
                    _birthDate == null
                        ? '생년월일 선택'
                        : '${_birthDate!.year}.${_birthDate!.month.toString().padLeft(2, '0')}.${_birthDate!.day.toString().padLeft(2, '0')}',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Sex>(
                  value: _sex,
                  decoration: const InputDecoration(
                    hintText: '성별',
                    border: OutlineInputBorder(),
                  ),
                  items: [Sex.m, Sex.f]
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                      .toList(),
                  onChanged: (v) => setState(() => _sex = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  validator: (v) => Validators.required(v, '주소'),
                  decoration: const InputDecoration(
                    hintText: '주소',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: Validators.phone,
                  decoration: const InputDecoration(
                    hintText: '전화번호',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isLoading ? null : _handleSignup,
                    child: _isLoading
                        ? const LoadingSpinner(size: 20)
                        : const Text('가입하기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
