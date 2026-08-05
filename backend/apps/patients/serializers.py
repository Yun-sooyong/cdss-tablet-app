from rest_framework import serializers

from .models import Patient


class PatientSerializer(serializers.ModelSerializer):
    class Meta:
        model = Patient
        fields = [
            "id",
            "chart_number",
            "name",
            "birth_date",
            "sex",
            "address",
            "phone",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "chart_number", "created_at", "updated_at"]


class PatientSummarySerializer(serializers.ModelSerializer):
    """batch/job 응답에 끼워 넣는 최소 정보 — "이 분석은 누구 것인지"
    판독 맥락용. 주소/전화번호처럼 더 민감한 필드는 넣지 않는다
    (최일운 요청, 2026-08-04)."""

    class Meta:
        model = Patient
        fields = ["id", "chart_number", "name", "birth_date", "sex"]
        read_only_fields = fields


class PatientSearchQuerySerializer(serializers.Serializer):
    chart_number = serializers.CharField(required=False, allow_blank=True)
    phone = serializers.CharField(required=False, allow_blank=True)

    def validate(self, attrs):
        if not attrs.get("chart_number") and not attrs.get("phone"):
            raise serializers.ValidationError(
                "chart_number 또는 phone 중 하나는 필요합니다."
            )
        return attrs


class PatientRegisterSerializer(serializers.Serializer):
    """이메일/비밀번호 방식 환자 회원가입. 카카오 소셜 로그인은 별도(추후).

    별도 아이디(username) 없이 email을 로그인 식별자로 쓴다 — User.username에
    email 값을 그대로 저장(User 모델 자체는 안 바꿈, 로그인은 여전히
    POST /auth/login/에 username 필드로 보내되 값이 email인 것뿐).

    chart_number(선택) — 병원이 접수처에서 먼저 등록해둔 환자가 나중에
    앱 가입할 때, 새 Patient를 또 만들지 않고 기존 레코드에 계정을 붙이기
    위한 연결 키. phone이 기존 레코드와 일치해야 연결된다(본인 확인).
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
    chart_number = serializers.CharField(
        max_length=20, required=False, allow_blank=True, default=""
    )


class PatientStaffCreateSerializer(serializers.Serializer):
    """의료진용 환자 등록(워크인) — 계정 없이 병원이 먼저 정보를 보유한다."""

    name = serializers.CharField(max_length=100)
    birth_date = serializers.DateField()
    sex = serializers.ChoiceField(choices=Patient.Sex.choices, default=Patient.Sex.UNKNOWN)
    phone = serializers.CharField(max_length=30)
    address = serializers.CharField(
        max_length=255, required=False, allow_blank=True, default=""
    )
