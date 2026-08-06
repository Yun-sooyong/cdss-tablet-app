import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tablet/models/models.dart';
import 'package:tablet/providers/batch_provider.dart';

/// 서버 알림 목록. 최신순으로 정렬해서 준다.
final notificationsProvider = FutureProvider<List<AppNotification>>((
  ref,
) async {
  final list = await ref.watch(analysisRepositoryProvider).fetchNotifications();
  final sorted = [...list]..sort((a, b) {
    final x = a.createdAt, y = b.createdAt;
    if (x == null || y == null) return 0;
    return y.compareTo(x); // 최신이 위
  });
  return sorted;
});

/// 사이드바 배지에 쓸 안읽음 개수.
/// 서버 `is_read` 를 그대로 믿는다 (읽음 처리 API가 생기기 전에는 로컬로
/// 마지막 조회 시각을 저장해 흉내냈지만, 이제 필요 없다).
final unreadCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider).value;
  if (list == null) return 0;
  return list.where((n) => !n.isRead).length;
});

/// 읽음 처리. 서버에 반영한 뒤 목록을 다시 받는다.
class NotificationActions {
  const NotificationActions(this._ref);
  final Ref _ref;

  Future<void> markRead(String id) async {
    await _ref.read(analysisRepositoryProvider).markNotificationRead(id);
    _ref.invalidate(notificationsProvider);
  }

  Future<void> markAllRead() async {
    await _ref.read(analysisRepositoryProvider).markAllNotificationsRead();
    _ref.invalidate(notificationsProvider);
  }
}

final notificationActionsProvider = Provider<NotificationActions>(
  NotificationActions.new,
);
