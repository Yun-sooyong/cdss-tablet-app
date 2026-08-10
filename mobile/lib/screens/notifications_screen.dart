import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../services/notification_feed_service.dart';
import '../widgets/loading_spinner.dart';

class NotificationsScreen extends StatefulWidget {
  final NotificationFeedService service;

  const NotificationsScreen({super.key, required this.service});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  String? _error;
  NotificationType? _filter;

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
      final list = await widget.service.fetchAll();
      if (!mounted) return;
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  List<AppNotification> get _filtered => _filter == null
      ? _notifications
      : _notifications.where((n) => n.type == _filter).toList();

  List<AppNotification> get _unread => _filtered.where((n) => !n.isRead).toList();
  List<AppNotification> get _older => _filtered.where((n) => n.isRead).toList();

  Future<void> _markRead(AppNotification n) async {
    if (n.isRead) return;
    setState(() => n.isRead = true);
    try {
      await widget.service.markRead(n.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => n.isRead = false);
    }
  }

  Future<void> _markAllRead() async {
    final previouslyUnread = _notifications.where((n) => !n.isRead).toList();
    setState(() {
      for (final n in _notifications) {
        n.isRead = true;
      }
    });
    try {
      await widget.service.markAllRead();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        for (final n in previouslyUnread) {
          n.isRead = false;
        }
      });
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('알림')),
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
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 16),
                        OutlinedButton(onPressed: _load, child: const Text('다시 시도')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _CategoryChip(
                                label: '전체',
                                selected: _filter == null,
                                onTap: () => setState(() => _filter = null),
                              ),
                              const SizedBox(width: 8),
                              ...const [
                                NotificationType.reservationConfirmed,
                                NotificationType.visitCreated,
                                NotificationType.prescriptionCreated,
                              ].map((t) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _CategoryChip(
                                      label: t.label,
                                      selected: _filter == t,
                                      onTap: () => setState(
                                          () => _filter = _filter == t ? null : t),
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: _filtered.isEmpty
                            ? ListView(
                                // RefreshIndicator가 스크롤 가능한 자식을 필요로 해서
                                // 빈 상태에서도 ListView로 감쌈.
                                children: [_EmptyState(colorScheme: colorScheme)],
                              )
                            : ListView(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                children: [
                                  if (_unread.isNotEmpty) ...[
                                    Row(
                                      children: [
                                        const Text('새로운 알림',
                                            style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primary,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text('${_unread.length}',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                        const Spacer(),
                                        TextButton(
                                          onPressed: _markAllRead,
                                          child: const Text('모두 읽음'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ..._unread.map((n) => _NotificationCard(
                                          notification: n,
                                          dateLabel: _fmtDate(n.createdAt),
                                          onTap: () => _markRead(n),
                                        )),
                                    const SizedBox(height: 12),
                                  ],
                                  if (_older.isNotEmpty) ...[
                                    const Text('이전 알림',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    ..._older.map((n) => _NotificationCard(
                                          notification: n,
                                          dateLabel: _fmtDate(n.createdAt),
                                          onTap: () {},
                                        )),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: colorScheme.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : colorScheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: colorScheme.surfaceContainerHighest,
      side: BorderSide.none,
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final String dateLabel;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.dateLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final n = notification;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: !n.isRead ? colorScheme.primary.withOpacity(0.06) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: !n.isRead
              ? colorScheme.primary.withOpacity(0.3)
              : colorScheme.outline,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colorScheme.surfaceContainerHighest,
                child: Icon(n.type.icon, color: colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!n.isRead) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('NEW',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(n.type.label,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(n.body,
                        style: TextStyle(
                            fontSize: 13, color: colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Text(dateLabel,
                        style: TextStyle(
                            fontSize: 11, color: colorScheme.onSurfaceVariant)),
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

class _EmptyState extends StatelessWidget {
  final ColorScheme colorScheme;
  const _EmptyState({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: colorScheme.surfaceContainerHighest,
              child: Icon(Icons.notifications_none,
                  size: 44, color: colorScheme.primary),
            ),
            const SizedBox(height: 20),
            const Text('알림이 없어요',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('새로운 알림이 오면\n여기에 표시될 거예요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
