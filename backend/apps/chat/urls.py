from django.urls import path

from . import views

urlpatterns = [
    path(
        "firebase-token/",
        views.ChatFirebaseTokenView.as_view(),
        name="chat-firebase-token",
    ),
]
