import 'package:flutter/material.dart';
import '../models/prescription.dart';
import '../services/medication_service.dart';
import '../widgets/loading_spinner.dart';

class PrescriptionInfoScreen extends StatefulWidget {
  final MedicationService medicationService;
  const PrescriptionInfoScreen({super.key, required this.medicationService});
  @override
  State<PrescriptionInfoScreen> createState() => _PrescriptionInfoScreenState();
}

class _PrescriptionInfoScreenState extends State<PrescriptionInfoScreen> {
  List<Prescription> _prescriptions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await widget.medicationService.fetchPrescriptions();
      if (!mounted) return;
      setState(() {
        _prescriptions = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('처방 내역')),
      body: _isLoading
          ? const Center(child: LoadingSpinner())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            color: colorScheme.onSurfaceVariant, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          '처방 내역을 불러오지 못했어요.\n$_error',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                            onPressed: _load, child: const Text('다시 시도')),
                      ],
                    ),
                  ),
                )
              : _prescriptions.isEmpty
                  ? Center(
                      child: Text('처방 내역이 없어',
                          style: TextStyle(color: colorScheme.onSurfaceVariant)))
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
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 8),
                                ...p.drugs.map((d) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: colorScheme
                                                .surfaceContainerHighest,
                                            child: Icon(
                                                Icons.medication_outlined,
                                                color: colorScheme.primary,
                                                size: 16),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(d.productName,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                                Text(d.dosageInfo,
                                                    style: TextStyle(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                        fontSize: 13)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
