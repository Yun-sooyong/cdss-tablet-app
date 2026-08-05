import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../services/auth_service.dart';
import '../widgets/loading_spinner.dart';

enum _SignupPath { newPatient, existingPatient }

class SignupScreen extends StatefulWidget {
  final AuthService authService;
  const SignupScreen({super.key, required this.authService});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  _SignupPath _path = _SignupPath.newPatient;

  final _nameController = TextEditingController();
  final _chartNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  Sex? _sex;
  DateTime? _birthDate;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _chartNumberController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_path == _SignupPath.newPatient) {
      if (_sex == null) {
        setState(() => _error = '성별을 선택해줘');
        return;
      }
      if (_birthDate == null) {
        setState(() => _error = '생년월일을 선택해줘');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await widget.authService.signUp(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        chartNumber: _path == _SignupPath.existingPatient
            ? _chartNumberController.text.trim()
            : null,
        birthDate: _path == _SignupPath.newPatient ? _birthDate : null,
        sex: _path == _SignupPath.newPatient ? _sex : null,
        phone: _path == _SignupPath.newPatient
            ? _phoneController.text.trim()
            : null,
        address: _path == _SignupPath.newPatient
            ? _addressController.text.trim()
            : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('신규 환자'),
                        selected: _path == _SignupPath.newPatient,
                        onSelected: (_) =>
                            setState(() => _path = _SignupPath.newPatient),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('병원에 등록된 환자'),
                        selected: _path == _SignupPath.existingPatient,
                        onSelected: (_) =>
                            setState(() => _path = _SignupPath.existingPatient),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _path == _SignupPath.newPatient
                      ? '병원 진료 이력이 없다면 이거예요. 새로 환자 정보를 등록해요.'
                      : '접수처에서 미리 등록된 환자번호가 있다면 이거예요. 기존 기록에 계정만 연결해요.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                      labelText: '이름', border: OutlineInputBorder()),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '이름을 입력해줘' : null,
                ),
                const SizedBox(height: 12),
                if (_path == _SignupPath.existingPatient) ...[
                  TextFormField(
                    controller: _chartNumberController,
                    decoration: const InputDecoration(
                        labelText: '환자번호 (접수처에서 받은 번호)',
                        border: OutlineInputBorder()),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '환자번호를 입력해줘' : null,
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  OutlinedButton(
                    onPressed: _pickBirthDate,
                    child: Text(_birthDate == null
                        ? '생년월일 선택'
                        : '${_birthDate!.year}.${_birthDate!.month.toString().padLeft(2, '0')}.${_birthDate!.day.toString().padLeft(2, '0')}'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Sex>(
                    value: _sex,
                    decoration: const InputDecoration(
                        labelText: '성별', border: OutlineInputBorder()),
                    items: [Sex.m, Sex.f]
                        .map((s) =>
                            DropdownMenuItem(value: s, child: Text(s.label)))
                        .toList(),
                    onChanged: (v) => setState(() => _sex = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: '전화번호', border: OutlineInputBorder()),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '전화번호를 입력해줘' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                        labelText: '주소 (선택)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                      labelText: '아이디', border: OutlineInputBorder()),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '아이디를 입력해줘';
                    if (v.trim().length < 4) return '아이디는 4자 이상으로 해줘';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: '비밀번호',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return '비밀번호를 입력해줘';
                    if (v.length < 8) return '비밀번호는 8자 이상으로 해줘';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordConfirmController,
                  obscureText: _obscurePassword,
                  decoration: const InputDecoration(
                      labelText: '비밀번호 확인', border: OutlineInputBorder()),
                  validator: (v) =>
                      (v != _passwordController.text) ? '비밀번호가 일치하지 않아' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
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
