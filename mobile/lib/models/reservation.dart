enum ReservationStatus { upcoming, completed, canceled, noShow }

class Reservation {
  final String id;
  final DateTime dateTime;
  final String hospitalName; // 서울내과
  final String purpose; // 정기검진
  final String doctorName; // 김의사
  ReservationStatus status;

  Reservation({
    required this.id,
    required this.dateTime,
    required this.hospitalName,
    required this.purpose,
    required this.doctorName,
    this.status = ReservationStatus.upcoming,
  });

  bool get isUpcoming => status == ReservationStatus.upcoming;
}
