enum ReservationStatus { requested, confirmed, changed, canceled, noShow }

extension ReservationStatusLabel on ReservationStatus {
  String get label {
    switch (this) {
      case ReservationStatus.requested:
        return '예약 요청됨';
      case ReservationStatus.confirmed:
        return '예약 확정';
      case ReservationStatus.changed:
        return '일정 변경됨';
      case ReservationStatus.canceled:
        return '취소됨';
      case ReservationStatus.noShow:
        return '미방문';
    }
  }
}

enum VisitType { first, follow }

extension VisitTypeLabel on VisitType {
  String get label {
    switch (this) {
      case VisitType.first:
        return '초진';
      case VisitType.follow:
        return '재진';
    }
  }
}

class Reservation {
  final String id;
  DateTime dateTime;
  final String hospitalName;
  final String department;
  final String purpose;
  final String doctorName;
  ReservationStatus status;

  Reservation({
    required this.id,
    required this.dateTime,
    required this.hospitalName,
    required this.department,
    required this.purpose,
    required this.doctorName,
    this.status = ReservationStatus.requested,
  });

  bool get isUpcoming =>
      (status == ReservationStatus.requested ||
          status == ReservationStatus.confirmed ||
          status == ReservationStatus.changed) &&
      dateTime.isAfter(DateTime.now());
}
