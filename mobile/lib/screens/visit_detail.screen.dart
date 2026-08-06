import 'package:flutter/material.dart';
import '../models/visit.dart';

class VisitDetailScreen extends StatelessWidget {
  final Visit visit;

  const VisitDetailScreen({super.key, required this.visit});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            if (visit.diagnoses.isNotEmpty) ...[
              const Text('진단명',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              ...visit.diagnoses.map((d) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: d.isPrimary
                            ? colorScheme.primary.withOpacity(0.15)
                            : colorScheme.surfaceContainerHighest,
                        child: Icon(
                          d.isPrimary ? Icons.star : Icons.circle_outlined,
                          color: d.isPrimary
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          size: 18,
                        ),
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
                  color: visit.note.isNotEmpty
                      ? null
                      : colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}