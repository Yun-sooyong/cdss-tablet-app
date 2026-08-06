import 'package:flutter/material.dart';
import 'dose.dart' show toKoreaTime;

// 백엔드 Notification.Type 중 환자 앱에 실제로 내려오는 건 이 3종류뿐.
// (analysis_done/share/chat은 의료진 판독 콘솔용, account_request는 관리자용이라
// 환자 본인 알림 목록(GET /api/v1/notifications/)엔 나오지 않는다.)
enum NotificationType { reservationConfirmed, visitCreated, prescriptionCreated, unknown }

extension NotificationTypeX on NotificationType {
  static NotificationType fromApi(String value) {
    switch (value) {
      case 'reservation_confirmed':
        return NotificationType.reservationConfirmed;
      case 'visit_created':
        return NotificationType.visitCreated;
      case 'prescription_created':
        return NotificationType.prescriptionCreated;
      default:
        return NotificationType.unknown;
    }
  }

  String get label {
    switch (this) {
      case NotificationType.reservationConfirmed:
        return '예약';
      case NotificationType.visitCreated:
        return '진료 기록';
      case NotificationType.prescriptionCreated:
        return '처방';
      case NotificationType.unknown:
        return '알림';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.reservationConfirmed:
        return Icons.calendar_today_outlined;
      case NotificationType.visitCreated:
        return Icons.description_outlined;
      case NotificationType.prescriptionCreated:
        return Icons.medication_outlined;
      case NotificationType.unknown:
        return Icons.notifications_outlined;
    }
  }
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String body;
  final String? targetType;
  final String? targetId;
  bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.body,
    required this.targetType,
    required this.targetId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: NotificationTypeX.fromApi(json['type'] as String),
      body: json['body'] as String,
      targetType: json['target_type'] as String?,
      targetId: json['target_id']?.toString(),
      isRead: json['is_read'] as bool? ?? false,
      // 기기 타임존에 기대지 않고 한국 시간으로 고정 변환 (dose.dart와 동일한 이유).
      createdAt: toKoreaTime(DateTime.parse(json['created_at'] as String)),
    );
  }
}
