from rest_framework.exceptions import PermissionDenied


def get_staff_or_403(user):
    staff = getattr(user, "staff", None)
    if staff is None:
        raise PermissionDenied("의료진(staff) 계정이 아닙니다.")
    return staff
