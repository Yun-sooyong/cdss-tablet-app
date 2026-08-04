from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .models import AuditLog, DeviceToken, Invitation, Notification, QRToken, User

admin.site.register(User, UserAdmin)
admin.site.register(Invitation)
admin.site.register(QRToken)
admin.site.register(DeviceToken)
admin.site.register(Notification)
admin.site.register(AuditLog)
