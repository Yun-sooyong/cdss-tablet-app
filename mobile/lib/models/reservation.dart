enum ReservationStatus { upcoming, completed, canceled, noShow }

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
  DateTime dateTime; // 일정 수정 가능해야 하니까 final 뺐음
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
    this.status = ReservationStatus.upcoming,
  });

  bool get isUpcoming => status == ReservationStatus.upcoming;
}
