from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from apps.accounts.views import InvitationIssueView, InvitationRedeemView

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/v1/auth/login/", TokenObtainPairView.as_view(), name="token_obtain_pair"),
    path(
        "api/v1/auth/login/refresh/",
        TokenRefreshView.as_view(),
        name="token_refresh",
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
    path("api/v1/analysis/", include("apps.analysis.urls")),
    path("api/v1/patients/", include("apps.patients.urls")),
    path("api/schema/", SpectacularAPIView.as_view(), name="schema"),
    path(
        "api/docs/",
        SpectacularSwaggerView.as_view(url_name="schema"),
        name="swagger-ui",
    ),
]
