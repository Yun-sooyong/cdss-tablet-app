import 'package:flutter/material.dart';
<<<<<<< HEAD
import '../models/prescription.dart';
import '../services/medication_service.dart';
import '../theme/app_colors.dart';

class PrescriptionInfoScreen extends StatefulWidget {
  final MedicationService medicationService;

  const PrescriptionInfoScreen({super.key, required this.medicationService});

=======
import 'package:url_launcher/url_launcher.dart';
import '../models/prescription.dart';
import '../services/medication_service.dart';
import '../theme/app_colors.dart';
import '../widgets/loading_spinner.dart';

class PrescriptionInfoScreen extends StatefulWidget {
  final MedicationService medicationService;
  const PrescriptionInfoScreen({super.key, required this.medicationService});
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
  @override
  State<PrescriptionInfoScreen> createState() => _PrescriptionInfoScreenState();
}

class _PrescriptionInfoScreenState extends State<PrescriptionInfoScreen> {
  List<Prescription> _prescriptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await widget.medicationService.fetchPrescriptions();
    if (!mounted) return;
    setState(() {
      _prescriptions = list;
      _isLoading = false;
    });
  }

<<<<<<< HEAD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('처방 내역 · 약 설명')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _prescriptions.length,
              itemBuilder: (context, i) {
                final p = _prescriptions[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.medication_outlined,
                                color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(p.medicationName,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(p.dosageInfo,
                            style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text(p.description),
                        const SizedBox(height: 8),
                        Text(
                          '처방일 ${p.prescribedDate.year}.${p.prescribedDate.month}.${p.prescribedDate.day}',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
=======
  Future<void> _openFile(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('처방 내역')),
      body: _isLoading
          ? const Center(child: LoadingSpinner())
          : _prescriptions.isEmpty
              ? const Center(child: Text('처방 내역이 없어', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _prescriptions.length,
                  itemBuilder: (context, i) {
                    final p = _prescriptions[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '처방일 ${p.prescribedDate.year}.${p.prescribedDate.month}.${p.prescribedDate.day}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            ...p.drugs.map((d) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.medication_outlined, color: AppColors.primary, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(d.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                            Text(d.dosageInfo, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                            if (p.fileUrl != null) ...[
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.download_outlined),
                                label: const Text('처방전 파일 보기'),
                                onPressed: () => _openFile(p.fileUrl!),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
    );
  }
}
