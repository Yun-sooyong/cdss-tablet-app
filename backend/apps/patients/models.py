import hashlib
import secrets

from django.conf import settings
from django.db import models
from encrypted_model_fields.fields import EncryptedCharField, EncryptedDateField

from apps.common.models import BaseModel


def generate_chart_number() -> str:
    return "P" + secrets.token_hex(4).upper()  # 예: PA1B2C3D4


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
    first_visit_at = models.DateTimeField(null=True, blank=True)
    last_visit_at = models.DateTimeField(null=True, blank=True)
    deleted_at = models.DateTimeField(null=True, blank=True)  # soft delete, 물리삭제 금지

    class Meta:
        db_table = "patient"

    def save(self, *args, **kwargs):
        self.phone_hash = hashlib.sha256(self.phone.encode()).hexdigest()
        super().save(*args, **kwargs)

    def __str__(self):
        return str(self.id)
