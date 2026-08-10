import 'dart:convert';
import '../models/app_notification.dart';
import 'api_client.dart';

// 서버 알림 목록/읽음 처리 — flutter_local_notifications 기반 복약 알림
// (NotificationService)과는 다른 개념이라 서비스를 분리했다.
class NotificationFeedService {
  final _client = ApiClient.instance;

  Future<List<AppNotification>> fetchAll() async {
    final res = await _client.get('/api/v1/notifications/');
    if (res.statusCode != 200) {
      throw Exception('알림을 불러오지 못했어요.');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String id) async {
    final res = await _client.patch('/api/v1/notifications/$id/');
    if (res.statusCode != 200) {
      throw Exception('읽음 처리에 실패했어요.');
    }
  }

  Future<void> markAllRead() async {
    final res = await _client.post('/api/v1/notifications/read-all/');
    if (res.statusCode != 204) {
      throw Exception('전체 읽음 처리에 실패했어요.');
    }
  }
}
