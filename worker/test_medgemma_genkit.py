"""medgemma_genkit.py 단독 검증 — 전체 Celery 파이프라인 없이 이 파일만 테스트.

실제 Mosec 서버(/medgemma)가 떠있고 SSH 터널이 연결된 상태에서 실행해야 한다
(mosec.py의 call_medgemma를 그대로 쓰기 때문 — mock이 아니라 진짜 호출).
"""
import asyncio
import base64
import io
import traceback

import numpy as np

from pipeline.medgemma_genkit import (
    ReportInput,
    _build_visualization,
    generate_report,
    generate_report_flow,
)

FAKE_STATS = {
    "stil_value": 20.53,
    "sigma": 0.346,
    "n_valid": 20,
    "class_composition": {
        "tumor": 44.5, "stroma": 34.8, "immune": 8.9,
        "necrosis": 11.6, "other": 0.1,
    },
    "cp_value": 0.203,
    "lower": 0.9,
    "upper": 40.16,
    "abstain": False,
    "decision": "LOW",
}


def _fake_mc_stack():
    """진짜 세그멘테이션 결과 흉내 — 위쪽 tumor, 아래쪽 stroma로 반반 채운 가짜 마스크."""
    mc_stack = np.zeros((20, 64, 64), dtype=np.uint8)
    mc_stack[:, 32:, :] = 1  # stroma
    return mc_stack


def _debug_direct_call():
    """generate_report()의 try/except를 우회해서 진짜 에러(전체 traceback)를 본다."""
    image = _build_visualization(_fake_mc_stack())
    buf = io.BytesIO()
    image.save(buf, format="PNG")
    image_png_b64 = base64.b64encode(buf.getvalue()).decode("ascii")

    return asyncio.run(
        generate_report_flow(
            ReportInput(stats=FAKE_STATS, image_png_b64=image_png_b64, job_id="test-genkit-1")
        )
    )


if __name__ == "__main__":
    print("[test] 1) wrapper(generate_report)로 먼저 시도...")
    report = generate_report(FAKE_STATS, _fake_mc_stack(), job_id="test-genkit-1")
    print("\n[결과]")
    for k, v in report.items():
        print(f"  {k}: {v}")

    if report["generation_failed"]:
        print("\n❌ 실패 — 진짜 원인을 보려고 flow를 직접 호출합니다 (전체 traceback 출력):\n")
        try:
            _debug_direct_call()
        except Exception:
            traceback.print_exc()
    else:
        print("\n✅ 성공 — segmentation_summary/findings가 채워졌으면 Genkit 구조가 정상 동작한 것.")
