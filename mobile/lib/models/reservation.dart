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

// 백엔드 Reservation.DocumentType과 1:1로 맞춘 값 — 문자열을 손으로 맞추다 어긋나는 일이
// 없게, 여기 값이 곧 서버에 보내는/받는 값의 유일한 소스다.
enum ReservationDocumentType {
  none,
  medicalCertificate,
  opinion,
  visitConfirmation,
  prescriptionReissue,
}

extension ReservationDocumentTypeX on ReservationDocumentType {
  static ReservationDocumentType fromApi(String? value) {
    switch (value) {
      case 'MEDICAL_CERTIFICATE':
        return ReservationDocumentType.medicalCertificate;
      case 'OPINION':
        return ReservationDocumentType.opinion;
      case 'VISIT_CONFIRMATION':
        return ReservationDocumentType.visitConfirmation;
      case 'PRESCRIPTION_REISSUE':
        return ReservationDocumentType.prescriptionReissue;
      default:
        return ReservationDocumentType.none;
    }
  }

  String get apiValue {
    switch (this) {
      case ReservationDocumentType.none:
        return 'NONE';
      case ReservationDocumentType.medicalCertificate:
        return 'MEDICAL_CERTIFICATE';
      case ReservationDocumentType.opinion:
        return 'OPINION';
      case ReservationDocumentType.visitConfirmation:
        return 'VISIT_CONFIRMATION';
      case ReservationDocumentType.prescriptionReissue:
        return 'PRESCRIPTION_REISSUE';
    }
  }

  String get label {
    switch (this) {
      case ReservationDocumentType.none:
        return '해당 없음';
      case ReservationDocumentType.medicalCertificate:
        return '진단서';
      case ReservationDocumentType.opinion:
        return '소견서';
      case ReservationDocumentType.visitConfirmation:
        return '진료확인서';
      case ReservationDocumentType.prescriptionReissue:
        return '처방전 재발급';
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
  final String reason;
  final ReservationDocumentType documentType;
  final String doctorName;
  ReservationStatus status;

  Reservation({
    required this.id,
    required this.dateTime,
    required this.hospitalName,
    required this.department,
    required this.reason,
    required this.documentType,
    required this.doctorName,
    this.status = ReservationStatus.requested,
  });

  bool get isUpcoming =>
      (status == ReservationStatus.requested ||
          status == ReservationStatus.confirmed ||
          status == ReservationStatus.changed) &&
      dateTime.isAfter(DateTime.now());
}
