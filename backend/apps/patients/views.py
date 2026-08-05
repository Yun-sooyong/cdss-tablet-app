import hashlib

from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import permissions, status
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.audit import log_access
from apps.common.permissions import get_patient_or_404, get_staff_or_403

from .models import Patient
from .serializers import (
    PatientRegisterSerializer,
    PatientSearchQuerySerializer,
    PatientSerializer,
    PatientStaffCreateSerializer,
    PatientSummarySerializer,
)


class PatientRegisterView(APIView):
    """아이디/비밀번호 방식 환자 회원가입 (2026-08-05, 이메일 방식에서
    변경 — 정은님 요청). 카카오 소셜 로그인(POST /auth/social/{provider})은
    별도로 나중에."""

    authentication_classes = []
    permission_classes = [permissions.AllowAny]

    @extend_schema(request=PatientRegisterSerializer, responses=PatientSerializer)
    def post(self, request):
        from apps.accounts.models import User

        serializer = PatientRegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        if User.objects.filter(username=data["username"]).exists():
            raise ValidationError("이미 사용 중인 아이디입니다.")

        # 병원이 접수처에서 먼저 등록해둔 환자(user=null)가 나중에 앱
        # 가입하는 경우 — 이름 + chart_number(uuid) 일치를 확인해 기존
        # 레코드에 계정을 붙인다. 없으면 기존과 동일하게 새로 만든다.
        # (정다희, 2026-08-05 — 매칭 키를 전화번호가 아니라 이름+차트번호로 결정)
        chart_number = data.get("chart_number", "")
        existing_patient = None
        if chart_number:
            existing_patient = Patient.objects.filter(
                chart_number=chart_number, user__isnull=True, deleted_at__isnull=True
            ).first()
            if existing_patient is None:
                raise ValidationError("차트번호를 찾을 수 없거나 이미 연결된 계정입니다.")
            if existing_patient.name != data["name"]:
                raise ValidationError("차트번호와 이름이 일치하지 않습니다.")

        user = User.objects.create_user(
            username=data["username"],
            password=data["password"],
        )

        if existing_patient:
            existing_patient.user = user
            existing_patient.save(update_fields=["user", "updated_at"])
            patient = existing_patient
        else:
            patient = Patient.objects.create(
                user=user,
                name=data["name"],
                birth_date=data["birth_date"],
                sex=data["sex"],
                phone=data["phone"],
                address=data.get("address", ""),
            )
        return Response(PatientSerializer(patient).data, status=status.HTTP_201_CREATED)


class PatientStaffCreateView(APIView):
    """의료진용 환자 등록(워크인) — 회원가입 여부와 무관하게 병원이 먼저
    환자 정보를 보유해야 한다는 요구사항으로 추가 (2026-08-05). 계정 없이
    Patient만 생성하고, chart_number를 나중에 환자가 앱 가입 시 계정
    연결 키로 쓴다 (PatientRegisterSerializer.chart_number 참고)."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(request=PatientStaffCreateSerializer, responses=PatientSerializer)
    def post(self, request):
        get_staff_or_403(request.user)

        serializer = PatientStaffCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        patient = Patient.objects.create(
            user=None,
            name=data["name"],
            birth_date=data["birth_date"],
            sex=data["sex"],
            phone=data["phone"],
            address=data.get("address", ""),
        )
        return Response(PatientSerializer(patient).data, status=status.HTTP_201_CREATED)


class PatientMeView(APIView):
    """설계문서 7.3절 — 환자 본인 데이터로만 제한."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=PatientSerializer)
    def get(self, request):
        patient = get_patient_or_404(request.user)
        from apps.accounts.models import AuditLog

        log_access(
            request,
            AuditLog.Action.READ,
            target_table="patient",
            target_id=patient.id,
            patient=patient,
        )
        return Response(PatientSerializer(patient).data)

    @extend_schema(request=PatientSerializer, responses=PatientSerializer)
    def patch(self, request):
        patient = get_patient_or_404(request.user)
        serializer = PatientSerializer(patient, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(PatientSerializer(patient).data)

    @extend_schema(request=None, responses=None)
    def delete(self, request):
        """회원탈퇴 — 설계문서 12장: is_active=false + 식별정보 가명처리,
        진료기록 본체는 보존(soft delete)."""
        patient = get_patient_or_404(request.user)

        user = request.user
        user.is_active = False
        user.save(update_fields=["is_active"])

        patient.name = "탈퇴한 회원"
        patient.address = ""
        patient.phone = ""
        patient.deleted_at = timezone.now()
        patient.save()

        return Response(status=status.HTTP_204_NO_CONTENT)


class PatientSearchView(APIView):
    """의료진용 환자 검색 — 최일운 요청, 2026-08-04.

    name/birth_date/phone은 암호화 컬럼이라 서버가 DB 레벨에서 LIKE·범위
    검색을 할 수 없다(모든 행을 복호화해야 해서 성능·보안 둘 다 안 좋음).
    그래서 검색 키는 두 개로 한정한다:
    - chart_number: 평문 인덱스 컬럼, 부분일치 가능
    - phone: phone_hash(SHA-256)로 정확히 일치하는 것만 (부분검색 불가)
    """

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=PatientSummarySerializer(many=True))
    def get(self, request):
        get_staff_or_403(request.user)

        serializer = PatientSearchQuerySerializer(data=request.query_params)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        qs = Patient.objects.filter(deleted_at__isnull=True)
        chart_number = data.get("chart_number")
        phone = data.get("phone")

        if chart_number:
            qs = qs.filter(chart_number__icontains=chart_number)
        else:
            phone_hash = hashlib.sha256(phone.encode()).hexdigest()
            qs = qs.filter(phone_hash=phone_hash)

        results = qs.order_by("chart_number")[:20]
        return Response(PatientSummarySerializer(results, many=True).data)
