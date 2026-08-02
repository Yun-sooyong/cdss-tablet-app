from django.contrib import admin
from django.urls import path

urlpatterns = [
    path("admin/", admin.site.urls),
    # TODO: path("api/v1/", include(...)) — 앱별 라우터 연결
]
