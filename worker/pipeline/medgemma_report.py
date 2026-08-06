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
OPINION_NOTE = (
    "위 의견은 AI가 제시하는 참고 소견이며 확정 진단·처방이 아닙니다. "
    "실제 치료 방향은 반드시 담당 의료진이 결정해야 합니다."
)

SYSTEM_PROMPT = """당신은 유방암 병리를 판독하는 전문의입니다.
주어진 세그멘테이션 이미지와 수치를 바탕으로 아래 JSON 형식으로만 답하세요.
다른 설명이나 인사말을 절대 붙이지 마세요.

⚠️ 중요 제약:
- sTIL은 "종양침윤림프구(Tumor-Infiltrating Lymphocytes) 비율"이라는 뜻입니다.
  이 용어를 다른 말로 풀어쓰거나, 존재하지 않는 의학 용어를 만들어내지 마세요.
- 특정 논문 수치, 생존율 통계, 약 이름·용량처럼 여기 주어지지 않은 사실을
  인용하거나 지어내지 마세요. ai_opinion에서도 마찬가지입니다 — "일반적으로",
  "~을 고려해볼 수 있다" 같은 조심스러운 표현을 쓰고, 존재를 확인할 수 없는
  구체적 수치·문헌은 언급하지 마세요.
- 확실하지 않은 내용은 추측해서 쓰지 마세요.
- 🔴 조직 구성비·sTIL 같은 **수치는 사용자 메시지에 주어진 값이 확정값**입니다.
  첨부 이미지를 눈대중으로 보고 비율을 다시 추정하거나, 주어진 수치와 다른
  값을 말하지 마세요. 이미지는 "어느 부위에 무엇이 몰려 있는지"(공간적 분포)를
  볼 때만 쓰고, 비율 자체는 주어진 숫자를 그대로 신뢰하세요.

{
  "segmentation_summary": "주어진 조직 구성비 수치를 기준으로, 종양 대비 면역세포
    비중이 어떤지·괴사 조직이 두드러지는지 등 구성 요소 간의 관계를 설명하세요.
    여기에 더해 첨부 이미지에서 읽을 수 있는 공간적 분포(면역세포가 종양 경계에
    몰려 있는지, 전체에 흩어져 있는지 등)를 덧붙이세요 (3~4문장).",
  "findings": "sTIL 수치·예측구간·판정 결과를 그대로 옮겨적지 말고, 다음을
    포함해 해석하세요: (1) 이 sTIL 수준이 위 조직 구성비와 일관되는지, (2) 예측
    구간 폭이 넓다면 그것이 판정 신뢰도에 시사하는 바, (3) 판정이 ABSTAIN(기권)
    이라면 어떤 점 때문에 경계선에 걸리는지, (4) 병리의가 육안으로 추가 확인하면
    좋을 소견 포인트. 수치를 그대로 재진술하는 문장으로 끝내지 마세요 (4~6문장).",
  "ai_opinion": "findings와는 구분되는, 당신의 임상적 '의견'을 서술하세요:
    이 케이스에서 특히 주의 깊게 봐야 할 부분이 무엇인지, sTIL 수준과 조직
    구성을 근거로 어떤 방향의 후속 조치(추가 검사, 치료 전략 논의 등)를
    고려해볼 만한지. 단정적 지시가 아니라 '~을 고려해볼 수 있습니다',
    '~일 가능성을 시사합니다' 같은 조심스러운 의견 어조로 서술하세요
    (2~4문장)."
}"""

# 클래스 인덱스는 til_conformal.py와 동일한 컨벤션 (0=tumor .. 4=other, 255=ignore)
# ⚠️ Mosec 쪽 inference._MASK_CLASS_COLORS와 같은 값이어야 한다 — 프론트엔드
#    오버레이와 MedGemma가 보는 그림의 색이 달라지면 안 된다.
CLASS_COLORS = {
    0: (230, 25, 75),    # tumor
    1: (60, 180, 75),    # stroma
    2: (255, 225, 25),   # immune
    3: (0, 130, 200),    # necrosis
    4: (128, 128, 128),  # other
}

# 🔴 2026-08-05 추가 — 이게 없으면 MedGemma는 알록달록한 그림만 받고 어떤 색이
#    무슨 조직인지 몰라서 자기 마음대로 추측한다. 색 해석이 뒤집히면 소견
#    문장이 통째로 반대가 되므로, 이미지를 보여줄 때 범례를 반드시 같이 준다.
IMAGE_LEGEND = (
    "첨부 이미지는 세그멘테이션 결과를 색으로 칠한 것입니다. 색상 범례:\n"
    "- 빨강: 종양(tumor)\n"
    "- 초록: 기질(stroma)\n"
    "- 노랑: 면역세포(immune)\n"
    "- 파랑: 괴사(necrosis)\n"
    "- 회색: 기타(other)\n"
    "- 검정: 판정 불가 영역(분석에서 제외됨)"
)


def _build_visualization(mc_stack: np.ndarray, max_size: int = 512) -> Image.Image:
    """MC 스택의 **다수결(consensus) 마스크**를 클래스별 색으로 칠해 시각화한다.

    원본 조직 이미지는 워커가 갖고 있지 않다(Mosec이 GCS에서 직접 읽으므로) —
    대신 이미 갖고 있는 세그멘테이션 결과를 색칠해서 MedGemma에 보여준다.
    원본 크기 그대로 보내면 네트워크/생성 속도가 느려지므로 축소한다.

    🔴 2026-08-05 버그 수정 — 예전에는 mc_stack[0](20회차 중 첫 번째 한 장)을
       썼다. 그런데 같이 넘기는 수치는 전부 다른 마스크 기준이었다:
         · stil_value        = 회차별 sTIL의 중앙값
         · class_composition = 다수결 마스크
         · 프론트엔드 오버레이 = 다수결 마스크
       MC Dropout은 회차마다 결과를 일부러 흔드는 기법이라(그 편차가 sigma다)
       0번 회차는 다수결 결과와 눈에 띄게 다를 수 있다. 그래서 MedGemma가
       "이미지상 면역세포가 거의 없다"고 쓰는데 수치는 sTIL 60%인 식으로
       리포트 문장과 수치가 어긋났다. 이제 다수결 마스크로 통일한다.

    ⚠️ 축소는 반드시 NEAREST로 한다. 기본 보간(BICUBIC)은 사진용이라 인접한
       색을 섞어버리는데, 라벨 색상은 섞으면 어느 클래스도 아닌 가짜 색이
       된다(빨강 tumor + 노랑 immune 사이에 주황이 생기는 식).
    """
    from pipeline.til_conformal import consensus_mask

    frame = consensus_mask(mc_stack)
    h, w = frame.shape
    rgb = np.zeros((h, w, 3), dtype=np.uint8)  # 나머지(=IGNORE)는 검정으로 남는다
    for cls, color in CLASS_COLORS.items():
        rgb[frame == cls] = color
    image = Image.fromarray(rgb)
    image.thumbnail((max_size, max_size), Image.NEAREST)
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
        comp_txt = f"조직 구성비(확정 실측값): {pairs}\n"

    return (
        f"sTIL: {stats['stil_value']}%\n"
        f"90% 예측구간: {stats['lower']}~{stats['upper']}%\n"
        f"50% 컷오프 기준: {decision_txt}\n"
        f"{comp_txt}"
        f"\n{IMAGE_LEGEND}\n"
        f"위 수치를 확정값으로 삼고, 첨부 이미지는 공간적 분포를 볼 때만 "
        f"참고해서 JSON을 채우세요."
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
            "ai_opinion": "",
            "disclaimer": DISCLAIMER,
            "opinion_note": OPINION_NOTE,
            "generation_failed": True,
        }

    image = _build_visualization(mc_stack)
    user_text = _build_user_text(stats)

    for _ in range(max_retries + 1):
        output = call_medgemma(image, SYSTEM_PROMPT, user_text, job_id=job_id, max_new_tokens=700)
        parsed = _parse_json(output)
        if parsed is not None and "findings" in parsed and "segmentation_summary" in parsed:
            return {
                "segmentation_summary": parsed["segmentation_summary"],
                "findings": parsed["findings"],
                "ai_opinion": parsed.get("ai_opinion", ""),
                "disclaimer": DISCLAIMER,
                "opinion_note": OPINION_NOTE,
                "generation_failed": False,
            }

    return {
        "segmentation_summary": "(자동 요약 생성 실패 — 수동 확인 필요)",
        "findings": "(판독 소견 생성 실패 — 재검토 권고)",
        "ai_opinion": "",
        "disclaimer": DISCLAIMER,
        "opinion_note": OPINION_NOTE,
        "generation_failed": True,
    }
