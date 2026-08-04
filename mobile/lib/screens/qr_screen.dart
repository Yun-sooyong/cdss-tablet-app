import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/qr_service.dart';
import '../theme/app_colors.dart';
import '../widgets/loading_spinner.dart';

class QrScreen extends StatefulWidget {
  final QrService qrService;

  const QrScreen({super.key, required this.qrService});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
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
    return Scaffold(
      appBar: AppBar(title: const Text('환자 확인용 QR')),
      body: Center(
        child: _isLoading
            ? const LoadingSpinner()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.surfaceMuted),
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
                      _token!.isExpired ? '유효시간이 만료되었어요' : '유효시간 ${_fmt(_token!.remaining)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _token!.isExpired ? Colors.red : null,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _reissue,
                        child: const Text('재발급'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
