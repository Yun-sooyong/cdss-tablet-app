"""환자용 알림(푸시) 트리거 — 서정은 요청, 2026-08-05.

signal로 붙인 이유: 지금 Visit/Prescription은 API로 만드는 경로가 아직
없고(의료진용 진료기록·처방 작성 화면이 아직 없음 — 지금은 스크립트로만
생성됨), Reservation 확정도 담당 의료진이 status를 CONFIRMED로 바꾸는
API가 아직 없다. 나중에 그 화면들이 어떤 API로 만들어지든(뷰 하나든
여러 개든) 이 신호는 모델 저장 시점에 항상 걸리므로 View 쪽에 알림
호출을 반복해서 넣지 않아도 된다.
"""

from django.db.models.signals import post_save, pre_save
from django.dispatch import receiver

from .models import Prescription, Reservation, Visit


@receiver(pre_save, sender=Reservation)
def _remember_previous_status(sender, instance, **kwargs):
    if not instance.pk:
        instance._previous_status = None
        return
    try:
        instance._previous_status = Reservation.objects.get(pk=instance.pk).status
    except Reservation.DoesNotExist:
        instance._previous_status = None


@receiver(post_save, sender=Reservation)
def notify_reservation_confirmed(sender, instance, created, **kwargs):
    if created:
        return
    previous = getattr(instance, "_previous_status", None)
    if previous == Reservation.Status.CONFIRMED or instance.status != Reservation.Status.CONFIRMED:
        return
    if not instance.patient.user_id:
        return

    from apps.accounts.services import notify

    notify(
        instance.patient.user,
        "reservation_confirmed",
        "예약이 확정되었습니다.",
        target_type="reservation",
        target_id=instance.id,
    )


@receiver(post_save, sender=Visit)
def notify_visit_created(sender, instance, created, **kwargs):
    if not created or not instance.patient.user_id:
        return

    from apps.accounts.services import notify

    notify(
        instance.patient.user,
        "visit_created",
        "새로운 진료 기록이 등록되었습니다.",
        target_type="visit",
        target_id=instance.id,
    )


@receiver(post_save, sender=Prescription)
def notify_prescription_created(sender, instance, created, **kwargs):
    if not created:
        return
    patient = instance.visit.patient
    if not patient.user_id:
        return

    from apps.accounts.services import notify

    notify(
        patient.user,
        "prescription_created",
        "새로운 처방전이 등록되었습니다.",
        target_type="prescription",
        target_id=instance.id,
    )
