from datetime import datetime, time, timedelta

from django.utils import timezone

from apps.common.gcs import generate_signed_url


def build_file_url(file_key: str) -> str:
    """처방전 파일 조회용 서명 URL(GET) 발급."""
    return generate_signed_url(file_key, method="GET")


# times_per_day -> 하루 중 복용 시각. 병원 표준 시간표가 따로 없어서
# 실사용 seed 데이터(정은님 테스트 계정, 2026-08-06)에서 쓴 값을 그대로
# 고정값으로 승격했다 — 나중에 필요해지면 설정으로 뺄 것.
_TIMES_PER_DAY_MAP = {
    1: [time(9, 0)],
    2: [time(9, 0), time(18, 0)],
    3: [time(8, 0), time(13, 0), time(19, 0)],
}


def generate_dose_schedules(prescription_drug, prescribed_at):
    """처방약 생성 시 dose_schedule을 같이 만든다 — 복약 캘린더/알림의
    근거가 dose_schedule이라(설계문서 6.6절), 이게 없으면 처방은 생겨도
    환자 앱엔 아무것도 안 뜬다. times_per_day가 매핑에 없는 값이면
    2회 기준 시간대로 대체한다."""
    from .models import DoseSchedule  # noqa: PLC0415 — 순환 임포트 회피

    times = _TIMES_PER_DAY_MAP.get(prescription_drug.times_per_day, _TIMES_PER_DAY_MAP[2])
    schedules = []
    for day_offset in range(prescription_drug.total_days):
        d = prescribed_at + timedelta(days=day_offset)
        for t in times:
            scheduled_at = timezone.make_aware(datetime.combine(d, t))
            schedules.append(
                DoseSchedule(prescription_drug=prescription_drug, scheduled_at=scheduled_at)
            )
    DoseSchedule.objects.bulk_create(schedules)
