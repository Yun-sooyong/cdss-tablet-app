import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/loading_spinner.dart';

class EditProfileScreen extends StatefulWidget {
  final AuthService authService;

  const EditProfileScreen({super.key, required this.authService});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  DateTime? _birthDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final patient = widget.authService.currentPatient;
    _nameController = TextEditingController(text: patient?.name ?? '');
    _addressController = TextEditingController(text: patient?.address ?? '');
    _phoneController = TextEditingController(text: patient?.phone ?? '');
    _birthDate = patient?.birthDate;
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('생년월일을 선택해줘')),
      );
      return;
    }
    setState(() => _isSaving = true);
    await widget.authService.updateProfile(
      name: _nameController.text.trim(),
      birthDate: _birthDate!,
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('개인정보가 수정되었습니다.')),
    );
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('개인정보 수정')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '이름', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _pickBirthDate,
              child: Text(_birthDate == null
                  ? '생년월일 선택'
                  : '${_birthDate!.year}.${_birthDate!.month.toString().padLeft(2, '0')}.${_birthDate!.day.toString().padLeft(2, '0')}'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: '주소', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '전화번호', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const LoadingSpinner(size: 20)
                    : const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
