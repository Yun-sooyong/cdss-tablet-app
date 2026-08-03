from rest_framework.exceptions import NotFound, PermissionDenied


def get_staff_or_403(user):
    staff = getattr(user, "staff", None)
    if staff is None:
        raise PermissionDenied("의료진(staff) 계정이 아닙니다.")
    return staff


def get_patient_or_404(user):
    patient = getattr(user, "patient", None)
    if patient is None:
        raise NotFound("환자 프로필이 없습니다.")
    return patient
