"""리포트 문장과 수치가 어긋나지 않는지 검증 (2026-08-05, 일운님 제보 버그).

증상: MedGemma가 쓴 소견 문장이 sTIL 수치/판정과 안 맞았다.
원인: MedGemma에게 보여주는 그림만 mc_stack[0](20회차 중 랜덤한 1장)이었고,
      같이 넘기는 수치(stil_value·class_composition)와 프론트엔드 오버레이는
      전부 다수결(consensus) 마스크 기준이었다.

이 테스트는 "화면·수치·MedGemma가 보는 그림이 전부 같은 한 장을 가리키는가"를
고정시킨다. 여기가 깨지면 리포트가 다시 엉뚱한 소리를 하기 시작한다.
"""
import numpy as np

from pipeline.medgemma_report import CLASS_COLORS, IMAGE_LEGEND, _build_user_text, _build_visualization
from pipeline.til_conformal import IGNORE_IDX, class_composition, consensus_mask

TUMOR, STROMA, IMMUNE = 0, 1, 2


def _stack_where_frame0_lies():
    """0번 회차만 전부 tumor, 나머지 19회차는 전부 immune인 MC 스택.

    다수결로는 immune이 압도적이지만, 예전 코드처럼 mc_stack[0]만 보면
    tumor라고 착각하게 되는 상황을 일부러 만든 것이다."""
    stack = np.full((20, 10, 10), IMMUNE, dtype=np.uint8)
    stack[0] = TUMOR
    return stack


def test_consensus_ignores_single_outlier_round():
    stack = _stack_where_frame0_lies()
    consensus = consensus_mask(stack)
    assert (consensus == IMMUNE).all(), "19대 1인데 다수결이 소수 의견을 따라감"


def test_consensus_marks_low_vote_pixels_as_ignore():
    """실제 클래스 득표가 과반에 못 미치면(=절반 이상이 255였으면) IGNORE로 남아야 한다."""
    stack = np.full((20, 4, 4), IGNORE_IDX, dtype=np.uint8)
    stack[:5] = TUMOR  # 20회 중 5회만 실제 클래스 — 과반 미달
    consensus = consensus_mask(stack)
    assert (consensus == IGNORE_IDX).all(), "과반 미달 픽셀이 유효 클래스로 잡힘"


def test_visualization_matches_consensus_not_first_frame():
    """🔴 이 버그의 핵심 회귀 테스트.
    MedGemma가 보는 그림이 다수결과 같아야 한다 — 0번 회차가 아니라."""
    stack = _stack_where_frame0_lies()
    rgb = np.asarray(_build_visualization(stack).convert("RGB"))

    immune_color = np.array(CLASS_COLORS[IMMUNE], dtype=np.uint8)
    tumor_color = np.array(CLASS_COLORS[TUMOR], dtype=np.uint8)

    assert (rgb == immune_color).all(axis=-1).all(), (
        "MedGemma가 보는 그림이 다수결(immune)과 다르다 — mc_stack[0]을 쓰고 있는 것 같다"
    )
    assert not (rgb == tumor_color).all(axis=-1).any(), "0번 회차(tumor)가 그림에 새어들어감"


def test_visualization_agrees_with_class_composition():
    """그림에서 센 색깔 비율이 수치로 넘기는 구성비와 일치해야 한다.
    둘이 어긋나면 MedGemma가 '이미지엔 X가 많은데 수치는 Y'라며 헷갈린다."""
    stack = np.full((20, 10, 10), STROMA, dtype=np.uint8)
    stack[:, :4, :] = IMMUNE      # 위쪽 40%는 immune
    stack[0] = TUMOR              # 0번 회차만 딴소리 — 다수결에 묻혀야 함

    comp = class_composition(stack)
    rgb = np.asarray(_build_visualization(stack).convert("RGB"))
    total = rgb.shape[0] * rgb.shape[1]

    for cls, name in ((IMMUNE, "immune"), (STROMA, "stroma")):
        color = np.array(CLASS_COLORS[cls], dtype=np.uint8)
        pct_in_image = (rgb == color).all(axis=-1).sum() / total * 100.0
        assert abs(pct_in_image - comp[name]) < 0.5, (
            f"{name}: 그림상 {pct_in_image:.1f}% vs 수치 {comp[name]}% — 서로 안 맞음"
        )


def test_downscale_does_not_invent_colors():
    """축소할 때 보간이 걸리면 클래스 색이 섞여 어느 조직도 아닌 색이 생긴다
    (빨강 tumor + 노랑 immune 사이의 주황 등). NEAREST면 안 생겨야 한다."""
    stack = np.zeros((3, 600, 600), dtype=np.uint8)
    stack[:, ::2, ::2] = TUMOR      # 체커보드 — 보간이 걸리면 최악인 패턴
    stack[:, 1::2, 1::2] = IMMUNE

    rgb = np.asarray(_build_visualization(stack, max_size=512).convert("RGB"))
    found = {tuple(c) for c in rgb.reshape(-1, 3)}
    allowed = set(CLASS_COLORS.values()) | {(0, 0, 0)}  # 검정 = IGNORE
    invented = found - allowed

    assert not invented, f"클래스에 없는 색이 생겼다(보간 발생): {sorted(invented)[:5]}"


def test_user_text_includes_color_legend():
    """색 범례가 빠지면 MedGemma는 어떤 색이 무슨 조직인지 몰라 추측하게 된다."""
    stats = {
        "stil_value": 62.5, "lower": 42.87, "upper": 82.13, "decision": "ABSTAIN",
        "class_composition": {"tumor": 30.0, "stroma": 25.0, "immune": 41.7,
                                "necrosis": 3.3, "other": 0.0},
    }
    text = _build_user_text(stats)
    assert IMAGE_LEGEND in text, "색상 범례가 프롬프트에 안 들어감"
    for word in ("빨강", "초록", "노랑"):
        assert word in text, f"범례에 '{word}'이 없음"


def test_user_text_marks_numbers_as_authoritative():
    """수치를 확정값으로 못박지 않으면 MedGemma가 이미지를 눈대중해서
    주어진 수치와 다른 비율을 말한다 — 이게 리포트 불일치의 직접 원인이었다."""
    stats = {
        "stil_value": 62.5, "lower": 42.87, "upper": 82.13, "decision": "HIGH",
        "class_composition": {"tumor": 30.0, "stroma": 25.0, "immune": 41.7,
                                "necrosis": 3.3, "other": 0.0},
    }
    text = _build_user_text(stats)
    assert "확정" in text, "주어진 수치가 확정값이라는 지시가 없음"


if __name__ == "__main__":
    import sys
    fns = [v for k, v in sorted(globals().items()) if k.startswith("test_") and callable(v)]
    failed = 0
    for fn in fns:
        try:
            fn()
            print(f"  PASS  {fn.__name__}")
        except AssertionError as e:
            print(f"  FAIL  {fn.__name__}: {e}")
            failed += 1
        except Exception as e:  # noqa: BLE001 — 예상 못한 에러도 FAIL로 집계
            print(f"  FAIL  {fn.__name__}: {type(e).__name__}: {e}")
            failed += 1
    print(f"\n{len(fns) - failed}/{len(fns)} passed")
    sys.exit(1 if failed else 0)
