import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared/theme/theme.dart';
import 'package:tablet/models/models.dart';
import 'package:tablet/providers/notification_provider.dart';
import 'package:tablet/router/routes.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider);
    final actions = ref.read(notificationActionsProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.gapXl,
            AppDimens.gapXl,
            AppDimens.gapXl,
            AppDimens.gapLg,
          ),
          child: Row(
            children: [
              Text('알림', style: theme.textTheme.titleLarge),
              const Spacer(),
              TextButton.icon(
                onPressed: unread == 0 ? null : actions.markAllRead,
                icon: const Icon(Icons.done_all),
                label: Text(unread == 0 ? '전부 읽음' : '전부 읽음 ($unread)'),
              ),
              const SizedBox(width: AppDimens.gapSm),
              IconButton(
                tooltip: '새로고침',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(notificationsProvider),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: items.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('불러오지 못했습니다\n$e')),
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    '알림이 없습니다',
                    style: TextStyle(color: theme.disabledColor),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(AppDimens.gapXl),
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppDimens.gapMd),
                itemBuilder: (context, i) => _NotificationCard(
                  notification: list[i],
                  onOpen: () => _open(context, ref, list[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 알림을 누르면 읽음 처리하고, 배치를 가리키면 그 배치로 이동한다.
  static void _open(BuildContext context, WidgetRef ref, AppNotification n) {
    if (!n.isRead) {
      ref.read(notificationActionsProvider).markRead(n.id);
    }
    final batchId = n.batchId;
    if (batchId != null) context.go(Routes.batch(batchId));
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onOpen});

  final AppNotification notification;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isNew = !notification.isRead;

    return Card(
      color: isNew ? cs.primary.withValues(alpha: 0.10) : theme.cardColor,
      child: ListTile(
        leading: Icon(
          _iconFor(notification.type),
          color: isNew ? cs.primary : theme.disabledColor,
        ),
        title: Text(notification.body),
        subtitle: Text(
          [
            _labelFor(notification.type),
            if (notification.createdAt != null) _when(notification.createdAt!),
          ].join(' · '),
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        trailing: notification.batchId == null
            ? (isNew ? const Icon(Icons.circle, size: 8) : null)
            : const Icon(Icons.chevron_right),
        onTap: onOpen,
      ),
    );
  }

  static IconData _iconFor(String type) => switch (type) {
    'analysis_done' => Icons.check_circle_outline,
    'analysis_failed' => Icons.error_outline,
    'share' => Icons.share_outlined,
    'account_request' => Icons.person_add_alt,
    _ => Icons.notifications_none,
  };

  static String _labelFor(String type) => switch (type) {
    'analysis_done' => '분석 완료',
    'analysis_failed' => '분석 실패',
    'share' => '공유',
    'account_request' => '계정 신청',
    _ => type,
  };

  static String _when(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return '방금';
    if (d.inHours < 1) return '${d.inMinutes}분 전';
    if (d.inDays < 1) return '${d.inHours}시간 전';
    if (d.inDays < 7) return '${d.inDays}일 전';
    return '${at.year}-${at.month.toString().padLeft(2, '0')}-'
        '${at.day.toString().padLeft(2, '0')}';
  }
}
