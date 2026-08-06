"""여러 타일을 한 번에 돌려서 immune 0% 문제가 얼마나 자주 나는지 표로 뽑는다.

    python sweep_immune.py uploads/a.png uploads/b.png ...
    python sweep_immune.py --file keys.txt          (한 줄에 하나씩 적은 파일)
    python sweep_immune.py --file keys.txt --model attention_unet_v1

한 장만 보고 "모델이 고장났다"고 단정하면 틀린다(실제로 그럴 뻔했다).
여러 장을 돌려서 immune 0%가 예외인지 패턴인지부터 확인한다.

특히 보려는 것: **necrosis 비율이 높은 타일일수록 immune이 0에 가까운가?**
괴사 주변 염증세포는 핵붕괴 잔해와 형태가 비슷해서 모델이 헷갈릴 수 있다.
그 상관이 보이면 "괴사가 많은 타일에서 림프구를 놓친다"는 재현 가능한
편향이고, 안 보이면 그냥 개별 타일의 우연한 실패다.

⚠️ 타일 하나당 MC Dropout 20회라 1~2분씩 걸린다. 5장이면 10분쯤 잡을 것.
⚠️ 아무것도 바꾸지 않는다 — 읽고 세어보기만 한다.
"""
import sys
import time

from dotenv import load_dotenv

# clients.mosec은 import 시점에 환경변수를 읽는다 — 반드시 그 전에 불러야 한다.
load_dotenv()

from clients.mosec import call_segmentation  # noqa: E402
from pipeline.til_conformal import (  # noqa: E402
    class_composition,
    compute_stil_and_conformal,
)

CONFORMAL_Q = 19.629


def parse_args(argv):
    keys, model, i = [], "attention_unet_v1", 0
    while i < len(argv):
        if argv[i] == "--model":
            model = argv[i + 1]
            i += 2
        elif argv[i] == "--file":
            with open(argv[i + 1], encoding="utf-8") as fh:
                keys += [ln.strip() for ln in fh if ln.strip() and not ln.startswith("#")]
            i += 2
        else:
            keys.append(argv[i])
            i += 1
    return keys, model


def short(key: str, width: int = 26) -> str:
    name = key.rsplit("/", 1)[-1]
    return name if len(name) <= width else name[: width - 1] + "…"


def main():
    argv = sys.argv[1:]
    if not argv:
        print(__doc__)
        return 1

    keys, model = parse_args(argv)

    import clients.mosec as mosec_client
    if not mosec_client.GCS_BUCKET:
        print("❌ GCS_BUCKET이 비어있다 — worker\\ 폴더에서 실행했는지 확인할 것.")
        return 1

    print(f"\n대상 {len(keys)}장 / 모델 {model} / 버킷 {mosec_client.GCS_BUCKET}")
    print("타일당 1~2분 걸린다. 기다리는 동안 창을 닫지 말 것.\n")

    header = f"{'타일':<27}{'tumor':>7}{'stroma':>8}{'immune':>8}{'necro':>7}{'sTIL':>8}  판정"
    print(header)
    print("-" * len(header))

    rows = []
    for key in keys:
        job_id = f"sweep-{int(time.time() * 1000)}"
        try:
            mc_stack, _ = call_segmentation(key, model, job_id=job_id)
        except Exception as exc:  # noqa: BLE001 — 한 장 실패해도 나머지는 계속
            print(f"{short(key):<27}  ❌ {type(exc).__name__}: {str(exc)[:60]}")
            continue

        comp = class_composition(mc_stack) or {}
        stats = compute_stil_and_conformal(mc_stack, CONFORMAL_Q)
        stil = stats.get("stil_value")
        rows.append((key, comp, stil, stats.get("decision")))

        stil_txt = "계산불가" if stil is None else f"{stil:.2f}%"
        print(f"{short(key):<27}"
              f"{comp.get('tumor', 0):>6.1f}%{comp.get('stroma', 0):>7.1f}%"
              f"{comp.get('immune', 0):>7.1f}%{comp.get('necrosis', 0):>6.1f}%"
              f"{stil_txt:>8}  {stats.get('decision')}")

    if not rows:
        print("\n성공한 타일이 없다 — image_key를 다시 확인할 것.")
        return 1

    # ── 요약 ────────────────────────────────────────────────────────────
    zero = [r for r in rows if r[1].get("immune", 0) == 0.0]
    print("\n" + "=" * 66)
    print(f"immune 0%인 타일: {len(zero)}/{len(rows)}장")

    if zero and len(zero) < len(rows):
        # necrosis 비율과의 상관을 눈으로 볼 수 있게 두 그룹의 평균을 비교한다.
        nonzero = [r for r in rows if r[1].get("immune", 0) > 0.0]
        avg = lambda rs, k: sum(r[1].get(k, 0) for r in rs) / len(rs)  # noqa: E731
        print(f"\n  immune 0%  그룹 평균 necrosis: {avg(zero, 'necrosis'):.1f}%")
        print(f"  immune>0%  그룹 평균 necrosis: {avg(nonzero, 'necrosis'):.1f}%")
        if avg(zero, "necrosis") > avg(nonzero, "necrosis") * 1.5:
            print("\n  ▶ 괴사가 많은 타일일수록 immune을 놓치는 경향이 보인다.")
            print("    괴사 주변 염증세포를 핵붕괴 잔해로 오분류하는 것으로 추정된다.")
            print("    → 재현 가능한 편향이므로 모델 담당자에게 전달할 가치가 있다.")
        else:
            print("\n  ▶ necrosis 비율과의 뚜렷한 상관은 안 보인다.")
            print("    다른 공통점(배율·염색·조직 유형)이 있는지 살펴볼 것.")
    elif not zero:
        print("\n  ▶ 전부 정상 — 앞서 본 타일이 예외적인 케이스였다.")
    else:
        print("\n  ▶ 전부 immune 0% — 타일 개별 문제가 아니라 모델 전반의 문제다.")
    print("=" * 66 + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
