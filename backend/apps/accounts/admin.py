from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .models import AccountRequest, AuditLog, DeviceToken, Notification, QRToken, User

admin.site.register(User, UserAdmin)
admin.site.register(QRToken)
admin.site.register(DeviceToken)
admin.site.register(Notification)
admin.site.register(AuditLog)


@admin.register(AccountRequest)
class AccountRequestAdmin(admin.ModelAdmin):
    """계정발급신청 조회 전용 화면. 승인/거절은 관리 콘솔의
    /auth/account-requests/{id}/approve|reject/ API로만 처리한다
    (최일운 요청, 2026-08-05) — 여기서 처리 액션까지 두면 API 경로와
    이중으로 처리될 수 있어 조회만 남겨뒀다."""

    list_display = ["name", "email", "role", "department", "status", "created_at"]
    list_filter = ["status", "role"]
    search_fields = ["name", "email"]
    readonly_fields = [
        "id",
        "name",
        "email",
        "role",
        "department",
        "note",
        "status",
        "reviewed_by",
        "created_user",
        "created_at",
        "reviewed_at",
    ]

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
