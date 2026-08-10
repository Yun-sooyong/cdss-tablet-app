import 'package:flutter/material.dart';
import '../models/reservation.dart';
import '../services/reservation_service.dart';
import '../widgets/loading_spinner.dart';
import 'document_detail_screen.dart';

class DocumentBoxScreen extends StatefulWidget {
  final ReservationService reservationService;

  const DocumentBoxScreen({super.key, required this.reservationService});

  @override
  State<DocumentBoxScreen> createState() => _DocumentBoxScreenState();
}

class _DocumentBoxScreenState extends State<DocumentBoxScreen> {
  List<Reservation> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await widget.reservationService.fetchDocumentRequests();
    if (!mounted) return;
    setState(() {
      _documents = list;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('문서함')),
      body: _isLoading
          ? const Center(child: LoadingSpinner())
          : _documents.isEmpty
              ? Center(
                  child: Text('신청한 서류가 없어요',
                      style: TextStyle(color: colorScheme.onSurfaceVariant)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _documents.length,
                  itemBuilder: (context, i) {
                    final r = _documents[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          child: Icon(Icons.description_outlined,
                              color: colorScheme.primary, size: 20),
                        ),
                        title: Text(r.documentType.label),
                        subtitle: Text(
                            '${r.dateTime.year}.${r.dateTime.month}.${r.dateTime.day} · ${r.department} · ${r.doctorName}'),
                        trailing: Text(r.status.label,
                            style:
                                TextStyle(color: colorScheme.onSurfaceVariant)),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  DocumentDetailScreen(reservation: r),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
