import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'edit_profile_screen.dart';

class MyInfoScreen extends StatefulWidget {
  final AuthService authService;

  const MyInfoScreen({super.key, required this.authService});

  @override
  State<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends State<MyInfoScreen> {
  Future<void> _goEdit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => EditProfileScreen(authService: widget.authService)),
    );
    // EditProfileScreen이 저장 성공하면 authService.currentPatient를 이미 갱신해두고 pop함.
    // 여기선 화면만 다시 그려주면 최신 값으로 보임.
    if (!mounted) return;
    setState(() {});
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '미입력';
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final patient = widget.authService.currentPatient;

    return Scaffold(
      appBar: AppBar(title: const Text('내 정보')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: '기본정보',
            surfaceColor: surface,
            rows: [
              _InfoRow(label: '이름', value: patient?.name ?? '미입력'),
              _InfoRow(label: '생년월일', value: _fmtDate(patient?.birthDate)),
              _InfoRow(
                label: '주소',
                value: (patient?.address?.isNotEmpty ?? false)
                    ? patient!.address!
                    : '미입력',
              ),
              _InfoRow(
                label: '전화번호',
                value: (patient?.phone?.isNotEmpty ?? false)
                    ? patient!.phone!
                    : '미입력',
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _goEdit,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                '정보 수정',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Color surfaceColor;
  final List<_InfoRow> rows;

  const _SectionCard(
      {required this.title, required this.surfaceColor, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
              width: 80,
              child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value, style: TextStyle(color: valueColor))),
        ],
      ),
    );
  }
}
