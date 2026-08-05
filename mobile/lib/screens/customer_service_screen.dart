import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';

// TODO: 실제 병원 연락처/주소/운영시간/문의 이메일로 교체 필요
const _kHospitalPhone = '02-0000-0000';
const _kHospitalAddress = '서울시 어딘가 123';
const _kHospitalHours = '평일 09:00 - 18:00 (점심시간 12:00 - 13:00, 주말/공휴일 휴진)';
const _kInquiryEmail = 'support@example.com';

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem({required this.question, required this.answer});
}

const List<_FaqItem> _kFaqItems = [
  _FaqItem(
    question: '예약은 어떻게 하나요?',
    answer:
        '홈 화면 또는 예약 관리 탭에서 "새 예약" 버튼을 눌러 진료과, 날짜, 시간을 순서대로 선택하면 예약 신청이 완료돼요.',
  ),
  _FaqItem(
    question: '예약을 취소하거나 변경하고 싶어요',
    answer: '예약 관리 화면의 "다가오는 예약"에서 원하는 예약을 선택하면 "일정 수정" 또는 "예약 취소"를 할 수 있어요.',
  ),
  _FaqItem(
    question: '복용 체크를 잘못 눌렀어요',
    answer: '약 관리 화면에서 복용 완료로 표시된 항목을 다시 누르면 체크가 취소돼요.',
  ),
  _FaqItem(
    question: '비밀번호를 잊어버렸어요',
    answer: '아직 비밀번호 재설정 기능은 준비 중이에요. 병원 고객센터로 문의해 주시면 도와드릴게요.',
  ),
  _FaqItem(
    question: '회원 탈퇴는 어떻게 하나요?',
    answer: '설정 화면 아래쪽의 "회원 탈퇴"를 눌러 안내에 따라 진행하면 돼요. 탈퇴 시 계정 정보는 복구할 수 없어요.',
  ),
  _FaqItem(
    question: '복약 알림이 오지 않아요',
    answer: '설정 화면에서 복약 알림이 켜져 있는지 확인하고, 휴대폰 설정에서 앱 알림 권한이 허용되어 있는지 확인해 주세요.',
  ),
];

class CustomerServiceScreen extends StatelessWidget {
  const CustomerServiceScreen({super.key});

  Future<void> _launch(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri);
    if (!ok) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('연결할 수 있는 앱을 찾지 못했어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('고객센터')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('병원 안내',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.call_outlined, color: AppColors.primary),
                  title: const Text('전화 문의'),
                  subtitle: const Text(_kHospitalPhone),
                  onTap: () => _launch(
                      context, Uri(scheme: 'tel', path: _kHospitalPhone)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.location_on_outlined,
                      color: AppColors.primary),
                  title: const Text('오시는 길'),
                  subtitle: const Text(_kHospitalAddress),
                  onTap: () => _launch(
                    context,
                    Uri.parse('https://maps.google.com/?q=$_kHospitalAddress'),
                  ),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.access_time_outlined,
                      color: AppColors.primary),
                  title: Text('운영시간'),
                  subtitle: Text(_kHospitalHours),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('문의하기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone_in_talk_outlined,
                      color: AppColors.primary),
                  title: const Text('전화로 문의하기'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _launch(
                      context, Uri(scheme: 'tel', path: _kHospitalPhone)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.email_outlined,
                      color: AppColors.primary),
                  title: const Text('이메일로 문의하기'),
                  subtitle: const Text(_kInquiryEmail),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _launch(
                    context,
                    Uri(
                      scheme: 'mailto',
                      path: _kInquiryEmail,
                      queryParameters: {'subject': 'V-Tree 문의'},
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('자주 묻는 질문',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: List.generate(_kFaqItems.length, (i) {
                final item = _kFaqItems[i];
                return Column(
                  children: [
                    if (i > 0) const Divider(height: 1),
                    ExpansionTile(
                      title: Text(item.question,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.answer,
                            style: const TextStyle(
                                color: Colors.grey, height: 1.5)),
                      ],
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
