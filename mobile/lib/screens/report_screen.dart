import 'package:flutter/material.dart';
import '../models/dose.dart';
import '../services/medication_service.dart';
import '../theme/app_colors.dart';
import '../widgets/loading_spinner.dart';

const _kWeekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

class ReportScreen extends StatefulWidget {
  final MedicationService medicationService;

  const ReportScreen({super.key, required this.medicationService});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  List<DailyDoseRecord> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final history = await widget.medicationService.fetchWeeklyDoseHistory();
    if (!mounted) return;
    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  double get _rate {
    if (_history.isEmpty) return 0;
    final doneCount = _history.where((r) => r.allTaken).length;
    return doneCount / _history.length;
  }

  String _weekdayLabel(DateTime d) => _kWeekdayLabels[d.weekday - 1];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(title: const Text('리포트')),
      body: _isLoading
          ? const Center(child: LoadingSpinner())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 64,
                                height: 64,
                                child: CircularProgressIndicator(
                                  value: _rate,
                                  strokeWidth: 6,
                                  backgroundColor:
                                      AppColors.primary.withOpacity(0.15),
                                  valueColor: const AlwaysStoppedAnimation(
                                      AppColors.primary),
                                ),
                              ),
                              Text('${(_rate * 100).round()}%',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('이번 주 복약률',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                '7일 중 ${_history.where((r) => r.allTaken).length}일 전체 복용 완료',
                                style: TextStyle(
                                    color: textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('일별 현황',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ..._history.map((record) {
                    final taken = record.doses.where((d) => d.taken).length;
                    final total = record.doses.length;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              _weekdayLabel(record.date),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            '${record.date.month}.${record.date.day}',
                            style:
                                TextStyle(color: textSecondary, fontSize: 13),
                          ),
                          const Spacer(),
                          Text(
                            total == 0 ? '복용 없음' : '$taken/$total 회',
                            style:
                                TextStyle(color: textSecondary, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            record.allTaken
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: record.allTaken
                                ? AppColors.primary
                                : textSecondary,
                            size: 20,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
