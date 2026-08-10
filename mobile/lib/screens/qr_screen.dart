import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/qr_service.dart';
import '../widgets/loading_spinner.dart';

class QrScreen extends StatefulWidget {
  final QrService qrService;

  const QrScreen({super.key, required this.qrService});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  // 서버가 발급 시각을 안 주기 때문에, API 스펙에 명시된 "5분 만료"를 고정값으로 써서
  // 진행바(남은 시간 비율)를 계산함. 백엔드가 만료 시간을 바꾸면 이 값도 같이 바꿔야 함.
  static const _totalDuration = Duration(minutes: 5);

  QrToken? _token;
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final token = await widget.qrService.issue();
    if (!mounted) return;
    setState(() {
      _token = token;
      _isLoading = false;
    });
  }

  Future<void> _reissue() async {
    setState(() => _isLoading = true);
    final token = await widget.qrService.reissue();
    if (!mounted) return;
    setState(() {
      _token = token;
      _isLoading = false;
    });
  }

  String _fmt(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = _token == null
        ? 0.0
        : (_token!.remaining.inSeconds / _totalDuration.inSeconds)
            .clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('환자 확인용 QR'),
        centerTitle: true,
      ),
      body: Center(
        child: _isLoading
            ? const LoadingSpinner()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/vtree_leaf_primary.png',
                        width: 40),
                    const SizedBox(height: 12),
                    Text(
                      '진료 접수를 위한\n환자 확인 QR입니다',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colorScheme.outline),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: QrImageView(
                          data: _token!.token,
                          size: 220,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _token!.isExpired
                          ? '유효시간이 만료되었어요'
                          : '유효시간 ${_fmt(_token!.remaining)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _token!.isExpired ? colorScheme.error : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(
                          _token!.isExpired
                              ? colorScheme.error
                              : colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.tonalIcon(
                        onPressed: _reissue,
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primary.withOpacity(0.12),
                          foregroundColor: colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text('재발급'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Image.asset('assets/images/vtree_leaf_primary.png',
                              width: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'QR 코드를 접수처에 보여주세요.\n빠르고 안전하게 진료를 진행할 수 있어요.',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ),
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
