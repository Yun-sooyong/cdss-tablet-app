import uuid

from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    """커스텀 User.

    필드는 앞으로 늘어나도 되지만(평범한 마이그레이션),
    AUTH_USER_MODEL 교체 자체는 최초 migrate 이후에 불가능하다.
    그래서 프로젝트 시작 시점에 미리 만들어 둔다.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    class Meta:
        db_table = "user"
