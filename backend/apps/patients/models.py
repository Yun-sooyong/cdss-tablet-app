import hashlib

from django.conf import settings
from django.db import models
from encrypted_model_fields.fields import EncryptedCharField, EncryptedDateField

from apps.common.models import BaseModel


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

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="patient"
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
