from rest_framework import serializers


class FirebaseTokenSerializer(serializers.Serializer):
    firebase_token = serializers.CharField()
    uid = serializers.CharField()
