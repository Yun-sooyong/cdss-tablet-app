from django.contrib import admin, messages
from django.contrib.auth.admin import UserAdmin
from django.utils import timezone
from django.utils.crypto import get_random_string

from .models import (
    AccountRequest,
    AuditLog,
    DeviceToken,
    Invitation,
    Notification,
    QRToken,
    User,
)

admin.site.register(User, UserAdmin)
admin.site.register(Invitation)
admin.site.register(QRToken)
admin.site.register(DeviceToken)
admin.site.register(Notification)
admin.site.register(AuditLog)


def _unique_username_from_email(email: str) -> str:
    base = email.split("@")[0] or "staff"
    username = base
    suffix = 1
    while User.objects.filter(username=username).exists():
        suffix += 1
        username = f"{base}{suffix}"
    return username


@admin.register(AccountRequest)
class AccountRequestAdmin(admin.ModelAdmin):
    """계정발급신청 처리 화면. 승인 액션이 실제 User+Staff를 만들고,
    생성된 임시 비밀번호는 화면에 한 번만 표시된다 — 관리자가 그걸
    복사해서 신청자에게 직접(카톡 등) 전달해야 한다. 저장은 안 되므로
    다시 볼 수 없다."""

    list_display = [
        "name",
        "email",
        "requested_role",
        "requested_department",
        "status",
        "created_at",
    ]
    list_filter = ["status", "requested_role"]
    search_fields = ["name", "email"]
    readonly_fields = ["created_user", "created_at", "reviewed_at"]
    actions = ["approve_requests", "reject_requests"]

    @admin.action(description="선택한 신청 승인 (계정 자동 생성)")
    def approve_requests(self, request, queryset):
        from apps.staff.models import Staff  # noqa: PLC0415 — 순환 임포트 회피

        for req in queryset.filter(status=AccountRequest.Status.PENDING):
            username = _unique_username_from_email(req.email)
            password = get_random_string(12)
            user = User.objects.create_user(
                username=username, email=req.email, password=password
            )
            Staff.objects.create(
                user=user,
                role=req.requested_role,
                department=req.requested_department,
            )
            req.status = AccountRequest.Status.APPROVED
            req.created_user = user
            req.reviewed_at = timezone.now()
            req.save(update_fields=["status", "created_user", "reviewed_at"])

            self.message_user(
                request,
                f"{req.name} 승인 완료 — 아이디: {username} / 임시 비밀번호: {password} "
                "(신청자에게 직접 전달하세요, 다시 조회할 수 없습니다)",
                level=messages.SUCCESS,
            )

    @admin.action(description="선택한 신청 거절")
    def reject_requests(self, request, queryset):
        updated = queryset.filter(status=AccountRequest.Status.PENDING).update(
            status=AccountRequest.Status.REJECTED, reviewed_at=timezone.now()
        )
        self.message_user(request, f"{updated}건 거절 처리했습니다.")
