"""immune 구성비가 0.0%로 나오는 원인 진단 (2026-08-05).

    python diagnose_immune.py uploads/실제이미지.png [model_name]

immune이 눈에 보이는 사진인데 class_composition에서 immune 0.0%가 나오는 문제를
두 가설로 갈라서 확인한다.

  가설 A — 클래스 인덱스가 어긋남
      모델이 내놓는 라벨 번호와 우리가 믿는 컨벤션(0=tumor,1=stroma,2=immune,
      3=necrosis,4=other)이 다르다. 이 경우 **어느 회차에도** 2번이 거의 없고,
      대신 다른 번호가 비정상적으로 많이 나온다.
      -> 처방: 클래스 매핑을 모델 학습 시점 기준으로 다시 맞춘다.

  가설 B — 다수결이 소수 클래스를 지운다
      회차마다 immune이 15%씩 나오는데 매번 '다른 자리'라서, 픽셀 하나하나로
      보면 immune이 항상 소수표라 다수결에서 전멸한다.
      -> 처방: 구성비를 sTIL과 같은 방식(회차별 계산 후 중앙값)으로 낸다.

이 스크립트는 아무것도 바꾸지 않는다 — 읽고 세어보기만 한다.
"""
import sys
import time

import numpy as np
from dotenv import load_dotenv

# ⚠️ 반드시 clients.mosec을 import하기 **전에** 불러야 한다.
#    clients/mosec.py는 모듈이 로드되는 순간 GCS_BUCKET/MOSEC_URL을 읽어서
#    전역에 박아두기 때문에, 나중에 부르면 이미 늦어서 빈 문자열이 남는다
#    (그러면 경로가 'gs:///uploads/...'처럼 버킷 없이 조립된다).
#    평소엔 celery_app.py가 대신 불러주지만, 이 스크립트는 그걸 거치지 않는다.
load_dotenv()

from clients.mosec import call_segmentation  # noqa: E402 — load_dotenv 이후여야 함
from pipeline.til_conformal import (  # noqa: E402
    CLASS_NAMES,
    IGNORE_IDX,
    IMMUNE_IDX,
    STROMA_IDX,
    class_composition,
    consensus_mask,
    stil_from_pred,
)


def _pct(count, total):
    return 0.0 if total == 0 else count / total * 100.0


def report(mc_stack: np.ndarray) -> None:
    n_rounds = mc_stack.shape[0]
    px_per_round = mc_stack.shape[1] * mc_stack.shape[2]

    print("\n" + "=" * 66)
    print(f"MC 스택 모양: {mc_stack.shape}  (회차 {n_rounds}개)")

    # ── 1. 원본 라벨에 어떤 번호들이 들어있나 ────────────────────────────
    values, counts = np.unique(mc_stack, return_counts=True)
    print("\n[1] 모델이 실제로 내놓은 라벨 번호 (전 회차 합산)")
    total_px = int(counts.sum())
    for v, c in zip(values, counts):
        name = "IGNORE" if v == IGNORE_IDX else (
            CLASS_NAMES[v] if v < len(CLASS_NAMES) else "❓정의되지 않은 번호")
        flag = "  ⚠️" if v != IGNORE_IDX and v >= len(CLASS_NAMES) else ""
        print(f"      {v:>3} = {name:<10} {_pct(int(c), total_px):6.2f}%{flag}")

    # ── 2. 회차별로 immune이 얼마나 나오나 ──────────────────────────────
    per_round_immune = [_pct(int((mc_stack[k] == IMMUNE_IDX).sum()), px_per_round)
                        for k in range(n_rounds)]
    per_round_stroma = [_pct(int((mc_stack[k] == STROMA_IDX).sum()), px_per_round)
                        for k in range(n_rounds)]
    per_round_stil = [stil_from_pred(mc_stack[k]) for k in range(n_rounds)]

    print("\n[2] 회차별 immune 비율 (개별 회차 안에서는 나오는가?)")
    print(f"      최소 {min(per_round_immune):.2f}% / 중앙값 "
          f"{float(np.median(per_round_immune)):.2f}% / 최대 {max(per_round_immune):.2f}%")
    print(f"      회차별 값: {[f'{v:.1f}' for v in per_round_immune]}")

    valid_stil = [s for s in per_round_stil if s is not None]
    if valid_stil:
        print(f"      회차별 sTIL 중앙값: {float(np.median(valid_stil)):.2f}%")

    # ── 3. 다수결을 통과하면 얼마가 남나 ────────────────────────────────
    consensus = consensus_mask(mc_stack)
    valid = consensus != IGNORE_IDX
    n_valid = int(valid.sum())
    cons_immune = _pct(int((consensus == IMMUNE_IDX).sum()), n_valid)
    cons_stroma = _pct(int((consensus == STROMA_IDX).sum()), n_valid)

    print("\n[3] 다수결(consensus) 통과 후")
    print(f"      immune {cons_immune:.2f}%   stroma {cons_stroma:.2f}%")
    print(f"      class_composition() 결과: {class_composition(mc_stack)}")

    # ── 4. immune 픽셀이 어디서 죽었나 ──────────────────────────────────
    ever_immune = (mc_stack == IMMUNE_IDX).any(axis=0)
    n_ever = int(ever_immune.sum())
    print("\n[4] '한 번이라도 immune으로 찍힌' 픽셀의 운명")
    if n_ever == 0:
        print("      없음 — 어느 회차에서도 immune이 안 나왔다")
    else:
        immune_votes = (mc_stack == IMMUNE_IDX).sum(axis=0)[ever_immune]
        survived = int((consensus[ever_immune] == IMMUNE_IDX).sum())
        print(f"      해당 픽셀 수: {n_ever:,} ({_pct(n_ever, px_per_round):.2f}% of 전체)")
        print(f"      그 픽셀들이 받은 immune 표수: 중앙값 {float(np.median(immune_votes)):.1f}"
              f"/{n_rounds}표 (최대 {int(immune_votes.max())}표)")
        print(f"      다수결에서 살아남은 픽셀: {survived:,} ({_pct(survived, n_ever):.1f}%)")

    # ── 판정 ────────────────────────────────────────────────────────────
    print("\n" + "=" * 66)
    median_round_immune = float(np.median(per_round_immune))
    if median_round_immune < 0.5:
        print("▶ 가설 A 유력 — 개별 회차에서도 immune(2번)이 거의 안 나온다.")
        print("  [1]번 표에서 2번 대신 어떤 번호가 많은지 확인할 것.")
        print("  ❓정의되지 않은 번호가 보이면 클래스 매핑이 어긋난 것이 확실하다.")
    elif cons_immune < median_round_immune * 0.5:
        print("▶ 가설 B 확정 — 회차마다 immune이 나오는데 다수결에서 지워진다.")
        print(f"  회차별 {median_round_immune:.2f}% → 다수결 후 {cons_immune:.2f}%")
        print("  매 회차 immune 자리가 달라서 픽셀별로는 항상 소수표가 된 것이다.")
        print("  ▷ 구성비를 sTIL과 같은 방식(회차별 계산 후 중앙값)으로 바꿔야 한다.")
    else:
        print("▶ 두 가설 모두 아님 — 다수결은 정상 작동 중이다.")
        print(f"  회차별 {median_round_immune:.2f}% → 다수결 후 {cons_immune:.2f}%")
        print("  이미지 자체에 immune이 적을 가능성 — 원본 사진과 대조할 것.")
    print("=" * 66 + "\n")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    image_key = sys.argv[1]
    model_name = sys.argv[2] if len(sys.argv) > 2 else "unet_v1"

    # .env를 못 읽었으면 버킷이 빈 문자열이라 'gs:///...' 같은 경로가 조립된다.
    # 그대로 두면 Mosec이 422로 거절하는데 원인이 한눈에 안 보이므로 여기서 막는다.
    import clients.mosec as mosec_client
    if not mosec_client.GCS_BUCKET:
        print("❌ GCS_BUCKET이 비어있다 — worker/.env를 못 읽었다.")
        print("   이 폴더(worker\\)에서 실행했는지, .env 파일이 있는지 확인할 것.")
        return 1

    # 🔴 job_id를 매번 다르게 만든다.
    #    Mosec은 마스크를 masks/{job_id}.png에 if_generation_match=0(이미 있으면
    #    건너뛰기)으로 올린다 — 삭제 권한이 없어서 일부러 그렇게 해뒀다.
    #    그래서 job_id를 "diagnose"로 고정해두면 두 번째 실행부터는 마스크가
    #    갱신되지 않고, 첫 회차(예: 더미 모델) 그림이 계속 남아서 수치와
    #    그림이 서로 다른 회차를 가리키게 된다. 실제로 이것 때문에 한참 헤맸다.
    job_id = f"diagnose-{model_name}-{int(time.time())}"

    print(f"Mosec 호출 중… image_key={image_key}, model={model_name}")
    print(f"  버킷: {mosec_client.GCS_BUCKET} / Mosec: {mosec_client.MOSEC_URL}")
    mc_stack, mask_key = call_segmentation(image_key, model_name, job_id=job_id)
    print(f"받음 — mask_key={mask_key}  ← 이 파일을 GCS 콘솔에서 열어볼 것")
    report(mc_stack)
    return 0


if __name__ == "__main__":
    sys.exit(main())
