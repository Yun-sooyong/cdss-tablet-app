"""Firebase Admin SDK 초기화.

키 파일 없이 Application Default Credentials(ADC)로 초기화한다 — Cloud
Run 자체 서비스 계정에 roles/firebasecloudmessaging.admin이 부여돼
있으면 그걸로 동작한다 (조직 정책으로 서비스 계정 키 발급 자체가
막혀 있어서 키 파일 방식은 애초에 못 씀 — worker GCS 접근과 동일한
이유).
"""

_app = None


def get_firebase_app():
    global _app
    if _app is None:
        import firebase_admin

        _app = firebase_admin.initialize_app()
    return _app
