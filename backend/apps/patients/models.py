import hashlib
import secrets

from django.conf import settings
from django.db import IntegrityError, models, transaction
from encrypted_model_fields.fields import EncryptedCharField, EncryptedDateField

from apps.common.models import BaseModel

CHART_NUMBER_SAVE_RETRIES = 5


def generate_chart_number() -> str:
    """4바이트(2^32)로는 생일역설 때문에 환자 6만 명 선에서 충돌 확률이
    50%를 넘어간다. 6바이트(2^48)로 늘려 여유를 둔다 (정다희, 2026-08-05).

    이 함수는 마이그레이션 재실행(테이블 재구성) 중에도 호출될 수 있어서
    여기서 DB를 조회하면 안 된다 — 남는 충돌 가능성은 Patient.save()에서
    저장 시점에 재시도로 처리한다.
    """
    return "P" + secrets.token_hex(6).upper()  # 예: PA1B2C3D4E5F


class Patient(BaseModel):
    """설계문서 6.3절.

    name/birth_date/address/phone은 컬럼 단위로 암호화한다
    (django-encrypted-model-fields, FIELD_ENCRYPTION_KEY).
    phone은 암호화되어 있어 그 자체로는 검색이 안 되므로, 검색용
    해시(phone_hash)를 별도로 둔다.
    """

    class Sex(models.TextChoices):
        MALE = "M", "남성"
        FEMALE = "F", "여성"
        OTHER = "O", "기타"
        UNKNOWN = "U", "미상"

    # 병원 접수처에서 먼저 등록해둔("워크인") 환자는 아직 계정이 없을 수 있다
    # (정다희, 2026-08-04 — 앱 회원가입 여부와 무관하게 병원이 환자 정보를
    # 보유해야 한다는 요구사항 추가). chart_number를 계정 연결 키로 쓴다.
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="patient",
        null=True,
        blank=True,
    )
    # 차트번호 — 최일운 요청(2026-08-04): name/birth_date/phone은 전부
    # 암호화 컬럼이라 LIKE/범위 검색이 안 돼서, 검색 가능한 평문 식별자가
    # 따로 필요했다. 그 자체로는 이름·생년월일 같은 개인정보를 담지 않는
    # 내부 참조 코드라 암호화 대상이 아니다.
    chart_number = models.CharField(
        max_length=20, unique=True, db_index=True, default=generate_chart_number, editable=False
    )
    name = EncryptedCharField(max_length=100)
    birth_date = EncryptedDateField()  # 나이가 아닌 생년월일로 저장
    sex = models.CharField(max_length=1, choices=Sex.choices, default=Sex.UNKNOWN)
    address = EncryptedCharField(max_length=255, blank=True)
    phone = EncryptedCharField(max_length=30)
    phone_hash = models.CharField(max_length=64, db_index=True, editable=False)
    # 접수처 시나리오(QR·앱 없는 환자, "성함이랑 생년월일 불러주세요") 검색용
    # — 윤수용 요청, 2026-08-05. phone_hash와 동일 패턴. 이름/생년월일 둘 다
    # 정확히 일치해야만 찾아지는 정확match 전용 해시라 부분검색은 여전히 안 됨.
    name_dob_hash = models.CharField(max_length=64, db_index=True, editable=False)
    first_visit_at = models.DateTimeField(null=True, blank=True)
    last_visit_at = models.DateTimeField(null=True, blank=True)
    deleted_at = models.DateTimeField(null=True, blank=True)  # soft delete, 물리삭제 금지

    class Meta:
        db_table = "patient"

    def save(self, *args, **kwargs):
        self.phone_hash = hashlib.sha256(self.phone.encode()).hexdigest()
        normalized_name = (self.name or "").strip()
        dob = self.birth_date
        dob = dob.isoformat() if hasattr(dob, "isoformat") else (dob or "")
        self.name_dob_hash = hashlib.sha256(f"{normalized_name}|{dob}".encode()).hexdigest()

        if not self._state.adding:
            super().save(*args, **kwargs)
            return

        # 신규 생성 시에만: chart_number 충돌(희박하지만 가능)이 나면
        # 다른 제약 위반과 구분해서 재생성 후 재시도한다.
        for attempt in range(CHART_NUMBER_SAVE_RETRIES):
            try:
                with transaction.atomic():
                    super().save(*args, **kwargs)
                return
            except IntegrityError:
                collided = (
                    type(self)
                    .objects.filter(chart_number=self.chart_number)
                    .exclude(pk=self.pk)
                    .exists()
                )
                if not collided or attempt == CHART_NUMBER_SAVE_RETRIES - 1:
                    raise
                self.chart_number = generate_chart_number()

    def __str__(self):
        return str(self.id)
