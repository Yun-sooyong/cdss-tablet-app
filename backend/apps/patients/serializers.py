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
    """chart_number(부분일치) / phone(정확일치) / name+birth_date(정확일치)
    셋 중 하나. name+birth_date는 접수처 시나리오용 — 윤수용 요청,
    2026-08-05(QR·앱 없는 환자를 "성함이랑 생년월일" 불러받아 찾는 흐름)."""

    chart_number = serializers.CharField(required=False, allow_blank=True)
    phone = serializers.CharField(required=False, allow_blank=True)
    name = serializers.CharField(required=False, allow_blank=True)
    birth_date = serializers.DateField(required=False)

    def validate(self, attrs):
        has_name_dob = bool(attrs.get("name")) and bool(attrs.get("birth_date"))
        if attrs.get("name") and not attrs.get("birth_date"):
            raise serializers.ValidationError("name으로 검색하려면 birth_date도 같이 필요합니다.")
        if attrs.get("birth_date") and not attrs.get("name"):
            raise serializers.ValidationError("birth_date로 검색하려면 name도 같이 필요합니다.")
        if not attrs.get("chart_number") and not attrs.get("phone") and not has_name_dob:
            raise serializers.ValidationError(
                "chart_number, phone, name+birth_date 조합 중 하나는 필요합니다."
            )
        return attrs


class PatientRegisterSerializer(serializers.Serializer):
    """아이디/비밀번호 방식 환자 회원가입. 카카오 소셜 로그인은 별도(추후).

    이메일 필드는 뺐다 — 로그인 식별자는 본인이 직접 정하는 username
    (정은님 요청, 2026-08-05로 이메일 방식에서 변경). 로그인은 여전히
    POST /auth/login/에 username+password.

    chart_number(선택) — 병원이 접수처에서 먼저 등록해둔 환자가 나중에
    앱 가입할 때, 새 Patient를 또 만들지 않고 기존 레코드에 계정을 붙이기
    위한 연결 키. 이름이 기존 레코드와 일치해야 연결된다(본인 확인).
    이 연결 시점 외에는 chart_number로 로그인하는 기능은 없다 — 필요
    없다고 확인됨.
    """

    username = serializers.CharField(max_length=150)
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
