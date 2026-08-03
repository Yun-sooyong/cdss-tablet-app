"""가짜 AI 판독의 — 실제 MedGemma 호출 없이 파이프라인을 테스트하기 위한 목(mock).

진짜 연동(medgemma.py, Genkit 사용)은 모델을 어떻게 부를지
(자체 호스팅 GPU vs 관리형 API 등) 팀 결정이 아직 안 끝나서 나중에 만든다.
함수 이름(generate_report)과 반환 모양만 미리 맞춰두면,
결정이 나는 대로 이 파일 대신 medgemma.py를 부르기만 하면 교체가 끝난다.
"""


def generate_report(stats: dict) -> dict:
    """sTIL/conformal 계산 결과(stats)를 받아 판독 보고서를 만든다.

    지금은 진짜로 AI에게 묻지 않고, 고정된 가짜 문장을 돌려준다.
    """
    return {
        "summary": f"[가짜 보고서] sTIL {stats['stil_value']}%, 판정: {stats['decision']}",
        "generation_failed": False,
    }
