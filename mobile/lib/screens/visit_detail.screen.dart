import 'package:flutter/material.dart';
import '../models/visit.dart';
import '../theme/app_colors.dart';

class VisitDetailScreen extends StatelessWidget {
  final Visit visit;

  const VisitDetailScreen({super.key, required this.visit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('진료 상세')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${visit.date.year}.${visit.date.month.toString().padLeft(2, '0')}.${visit.date.day.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${visit.department}${visit.doctorName != null ? ' · ${visit.doctorName}' : ''}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            if (visit.diagnoses.isNotEmpty) ...[
              const Text('진단명',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              ...visit.diagnoses.map((d) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        d.isPrimary ? Icons.star : Icons.circle_outlined,
                        color: d.isPrimary ? AppColors.primary : Colors.grey,
                        size: 20,
                      ),
                      title: Text(d.nameKo),
                      subtitle: d.isPrimary ? const Text('주 진단') : null,
                    ),
                  )),
              const SizedBox(height: 12),
            ],
            const Text('의료진 메모',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              visit.note.isNotEmpty ? visit.note : '남겨진 메모가 없어요',
              style: TextStyle(
                  color: visit.note.isNotEmpty ? null : Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}