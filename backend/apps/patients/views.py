from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import get_patient_or_404

from .serializers import PatientSerializer


class PatientMeView(APIView):
    """설계문서 7.3절 — 환자 본인 데이터로만 제한."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=PatientSerializer)
    def get(self, request):
        patient = get_patient_or_404(request.user)
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
