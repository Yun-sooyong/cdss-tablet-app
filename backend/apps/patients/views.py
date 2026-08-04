from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import permissions, status
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.audit import log_access
from apps.common.permissions import get_patient_or_404

from .models import Patient
from .serializers import PatientRegisterSerializer, PatientSerializer


class PatientRegisterView(APIView):
    """설계문서 3.1-a — 아이디/비밀번호 방식 환자 회원가입.
    카카오 소셜 로그인(POST /auth/social/{provider})은 별도로 나중에."""

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

        user = User.objects.create_user(
            username=data["username"],
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
