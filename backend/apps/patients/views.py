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
    PatientSummarySerializer,
)


class PatientRegisterView(APIView):
    """설계문서 3.1-a — 이메일/비밀번호 방식 환자 회원가입.
    카카오 소셜 로그인(POST /auth/social/{provider})은 별도로 나중에."""

    authentication_classes = []
    permission_classes = [permissions.AllowAny]

    @extend_schema(request=PatientRegisterSerializer, responses=PatientSerializer)
    def post(self, request):
        from apps.accounts.models import User

        serializer = PatientRegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        if User.objects.filter(email=data["email"]).exists():
            raise ValidationError("이미 가입된 이메일입니다.")

        # User.username에 email을 그대로 넣는다 — 로그인은 여전히
        # POST /auth/login/ + username 필드지만, 값은 email이 된다.
        user = User.objects.create_user(
            username=data["email"],
            email=data["email"],
            password=data["password"],
        )
        patient = Patient.objects.create(
            user=user,
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
