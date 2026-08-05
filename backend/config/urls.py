from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from apps.accounts.views import (
    AuditLogListView,
    DeviceTokenRegisterView,
    InvitationIssueView,
    InvitationRedeemView,
    LogoutView,
    NotificationListView,
    NotificationReadAllView,
    NotificationReadView,
    PasswordChangeView,
    QRVerifyView,
)
from apps.analysis.views import UploadSignedUrlView
from apps.staff.views import DepartmentListView

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/v1/auth/login/", TokenObtainPairView.as_view(), name="token_obtain_pair"),
    path(
        "api/v1/auth/login/refresh/",
        TokenRefreshView.as_view(),
        name="token_refresh",
    ),
    path("api/v1/auth/logout/", LogoutView.as_view(), name="logout"),
    path(
        "api/v1/auth/password/change/",
        PasswordChangeView.as_view(),
        name="password-change",
    ),
    path(
        "api/v1/auth/invitations/redeem/",
        InvitationRedeemView.as_view(),
        name="invitation-redeem",
    ),
    path(
        "api/v1/staff/invitations/",
        InvitationIssueView.as_view(),
        name="invitation-issue",
    ),
    path("api/v1/qr/verify/", QRVerifyView.as_view(), name="qr-verify"),
    path(
        "api/v1/devices/tokens/",
        DeviceTokenRegisterView.as_view(),
        name="device-token-register",
    ),
    path(
        "api/v1/notifications/",
        NotificationListView.as_view(),
        name="notification-list",
    ),
    path(
        "api/v1/notifications/read-all/",
        NotificationReadAllView.as_view(),
        name="notification-read-all",
    ),
    path(
        "api/v1/notifications/<uuid:notification_id>/",
        NotificationReadView.as_view(),
        name="notification-read",
    ),
    path(
        "api/v1/uploads/signed-url/",
        UploadSignedUrlView.as_view(),
        name="upload-signed-url",
    ),
    path("api/v1/departments/", DepartmentListView.as_view(), name="department-list"),
    path("api/v1/audit-logs/", AuditLogListView.as_view(), name="audit-log-list"),
    path("api/v1/analysis/", include("apps.analysis.urls")),
    path("api/v1/chat/", include("apps.chat.urls")),
    path("api/v1/patients/", include("apps.patients.urls")),
    path("api/v1/staff/", include("apps.staff.urls")),
    path("api/v1/", include("apps.clinical.urls")),
    path("api/schema/", SpectacularAPIView.as_view(), name="schema"),
    path(
        "api/docs/",
        SpectacularSwaggerView.as_view(url_name="schema"),
        name="swagger-ui",
    ),
]
