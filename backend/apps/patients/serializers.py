from rest_framework import serializers

from .models import Patient


class PatientSerializer(serializers.ModelSerializer):
    class Meta:
        model = Patient
        fields = [
            "id",
            "name",
            "birth_date",
            "sex",
            "address",
            "phone",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]


class PatientSummarySerializer(serializers.ModelSerializer):
    """batch/job 응답에 끼워 넣는 최소 정보 — "이 분석은 누구 것인지"
    판독 맥락용. 주소/전화번호처럼 더 민감한 필드는 넣지 않는다
    (최일운 요청, 2026-08-04)."""

    class Meta:
        model = Patient
        fields = ["id", "name", "birth_date", "sex"]
        read_only_fields = fields


class PatientRegisterSerializer(serializers.Serializer):
    """이메일/비밀번호 방식 환자 회원가입. 카카오 소셜 로그인은 별도(추후).

    별도 아이디(username) 없이 email을 로그인 식별자로 쓴다 — User.username에
    email 값을 그대로 저장(User 모델 자체는 안 바꿈, 로그인은 여전히
    POST /auth/login/에 username 필드로 보내되 값이 email인 것뿐).
    """

    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, min_length=8)
    name = serializers.CharField(max_length=100)
    birth_date = serializers.DateField()
    sex = serializers.ChoiceField(choices=Patient.Sex.choices, default=Patient.Sex.UNKNOWN)
    phone = serializers.CharField(max_length=30)
    address = serializers.CharField(
        max_length=255, required=False, allow_blank=True, default=""
    )
