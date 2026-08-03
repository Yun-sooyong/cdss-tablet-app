import 'package:flutter/material.dart';
import '../models/reservation.dart';
import '../services/reservation_service.dart';
import '../theme/app_colors.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('문서함')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? const Center(
                  child:
                      Text('신청한 서류가 없어요', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _documents.length,
                  itemBuilder: (context, i) {
                    final r = _documents[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(Icons.description_outlined,
                            color: AppColors.primary),
                        title: Text(r.purpose.replaceFirst('서류 발급 · ', '')),
                        subtitle: Text(
                            '${r.dateTime.year}.${r.dateTime.month}.${r.dateTime.day} · ${r.department} · ${r.doctorName}'),
                        trailing: Text(r.status.name),
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
