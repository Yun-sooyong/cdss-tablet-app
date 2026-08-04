"""진짜 MedGemma 판독 보고서 생성 — clients/mosec.call_medgemma()로 GPU 서비스의
/medgemma 라우트를 호출한다.

medgemma_mock.py를 대체한다. 함수 이름(generate_report)은 다르다 —
mc_stack(시각화용 이미지 재료)이 추가로 필요해서 tasks.py 쪽 호출부도 같이 바뀐다.

⚠️ 프롬프트는 반드시 여기서만 만든다. sTIL 용어 할루시네이션을 막는 제약이
   SYSTEM_PROMPT에 들어있다 — GPU 서비스 쪽(medgemma_worker.py)은 받은 프롬프트를
   그대로 실행할 뿐 재구성하지 않는다.
"""
import json
import re
from typing import Optional

import numpy as np
from PIL import Image

from clients.mosec import call_medgemma

DISCLAIMER = "본 결과는 AI 보조 도구의 출력이며 의료진의 최종 판단이 필요합니다."

SYSTEM_PROMPT = """당신은 유방암 병리를 판독하는 전문의입니다.
주어진 세그멘테이션 이미지와 수치를 바탕으로 아래 JSON 형식으로만 답하세요.
다른 설명이나 인사말을 절대 붙이지 마세요.

⚠️ 중요: sTIL은 "종양침윤림프구(Tumor-Infiltrating Lymphocytes) 비율"이라는
뜻입니다. 이 용어를 다른 말로 풀어쓰거나, 존재하지 않는 의학 용어를
만들어내지 마세요. 주어진 수치와 이미지만 근거로 서술하고, 확실하지 않은
내용은 추측해서 쓰지 마세요.

{
  "segmentation_summary": "첨부 이미지의 조직 유형별 구성을 1~2문장으로 요약",
  "findings": "sTIL 수치와 불확실성(기권 여부)을 고려한 임상 판독 소견 (자연어 서술, 입력값 단순 반복 금지)"
}"""

# 클래스 인덱스는 til_conformal.py와 동일한 컨벤션 (0=tumor .. 4=other, 255=ignore)
CLASS_COLORS = {
    0: (230, 25, 75),    # tumor
    1: (60, 180, 75),    # stroma
    2: (255, 225, 25),   # immune
    3: (0, 130, 200),    # necrosis
    4: (128, 128, 128),  # other
}


def _build_visualization(mc_stack: np.ndarray, max_size: int = 512) -> Image.Image:
    """MC 스택의 대표 마스크(0번째 회차)를 클래스별 색으로 칠해 시각화 이미지로 만든다.

    원본 조직 이미지는 워커가 갖고 있지 않다(Mosec이 GCS에서 직접 읽으므로) —
    대신 이미 갖고 있는 세그멘테이션 결과를 색칠해서 MedGemma에 보여준다.
    원본 크기 그대로 보내면 네트워크/생성 속도가 느려지므로 축소한다.
    """
    frame = mc_stack[0]
    h, w = frame.shape
    rgb = np.zeros((h, w, 3), dtype=np.uint8)
    for cls, color in CLASS_COLORS.items():
        rgb[frame == cls] = color
    image = Image.fromarray(rgb)
    image.thumbnail((max_size, max_size))
    return image


def _build_user_text(stats: dict) -> str:
    decision_txt = {
        "ABSTAIN": "기권(예측구간이 50% 컷오프에 걸침 — 판정 유보)",
        "LOW": "자동 판정 가능 (LOW)",
        "HIGH": "자동 판정 가능 (HIGH)",
    }.get(stats["decision"], stats["decision"])

    comp_txt = ""
    if stats.get("class_composition"):
        pairs = " / ".join(f"{k} {v}%" for k, v in stats["class_composition"].items())
        comp_txt = f"조직 구성비(세그멘테이션 실측): {pairs}\n"

    return (
        f"sTIL: {stats['stil_value']}%\n"
        f"90% 예측구간: {stats['lower']}~{stats['upper']}%\n"
        f"50% 컷오프 기준: {decision_txt}\n"
        f"{comp_txt}"
        f"위 정보와 첨부 이미지를 근거로 JSON을 채우세요."
    )


def _parse_json(output: str) -> Optional[dict]:
    """MedGemma 출력에서 JSON만 안전 추출. ```json 감싸기 제거 후 첫 {..} 파싱.
    실패하면 None (호출부에서 재시도/폴백)."""
    cleaned = re.sub(r"```(?:json)?", "", output).strip()
    match = re.search(r"\{.*\}", cleaned, re.DOTALL)
    if not match:
        return None
    try:
        return json.loads(match.group(0))
    except json.JSONDecodeError:
        return None


def generate_report(stats: dict, mc_stack: np.ndarray, job_id: str = "",
                     max_retries: int = 2) -> dict:
    """sTIL/conformal 결과(stats) + 세그멘테이션 마스크(mc_stack)로 MedGemma
    판독 보고서를 생성한다. JSON 파싱 실패 시 재시도, 끝내 실패하면 폴백."""
    if stats.get("stil_value") is None:
        return {
            "segmentation_summary": "",
            "findings": "sTIL 계산 불가로 판독 보고서를 생성하지 않았습니다.",
            "disclaimer": DISCLAIMER,
            "generation_failed": True,
        }

    image = _build_visualization(mc_stack)
    user_text = _build_user_text(stats)

    for _ in range(max_retries + 1):
        output = call_medgemma(image, SYSTEM_PROMPT, user_text, job_id=job_id)
        parsed = _parse_json(output)
        if parsed is not None and "findings" in parsed and "segmentation_summary" in parsed:
            return {
                "segmentation_summary": parsed["segmentation_summary"],
                "findings": parsed["findings"],
                "disclaimer": DISCLAIMER,
                "generation_failed": False,
            }

    return {
        "segmentation_summary": "(자동 요약 생성 실패 — 수동 확인 필요)",
        "findings": "(판독 소견 생성 실패 — 재검토 권고)",
        "disclaimer": DISCLAIMER,
        "generation_failed": True,
    }
