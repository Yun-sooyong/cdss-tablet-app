"""Django가 하는 일을 흉내내서 우체통(Redis)에 진짜 쪽지 하나를 넣는다.

    python send_test_task.py uploads/실제이미지.png
    python send_test_task.py uploads/실제이미지.png --model attention_unet_v1
    python send_test_task.py uploads/실제이미지.png --wait     (결과까지 기다림)

⚠️ 2026-08-05 전면 수정 — 예전 버전은 이랬다:
       image_key="fake/image.png", model_version_id="v1", model_name 없음
   워커가 가짜 Mosec을 쓰던 시절엔 이걸로 충분했지만, 진짜 Mosec에 붙은
   지금은 두 가지 문제가 생긴다:
     1) fake/image.png는 GCS에 없어서 422로 죽는다.
     2) model_name이 없으면 "v1"이 모델 이름으로 넘어가는데, Mosec은 모르는
        이름을 받으면 **에러 없이** unet_v1(가중치 없는 DummyUNet)로 폴백한다.
        즉 성공한 것처럼 보이면서 의미 없는 수치가 나온다.
   그래서 실제 image_key를 인자로 받도록 바꾸고, model_name도 함께 보낸다.

   (지금은 clients/mosec.py가 폴백을 감지해서 막아주지만, 애초에 올바른
    값을 보내는 게 먼저다.)
"""
import sys
import uuid

from dotenv import load_dotenv

load_dotenv()

from celery_app import app  # noqa: E402

CONFORMAL_Q = 19.629


def main():
    argv = sys.argv[1:]
    if not argv:
        print(__doc__)
        return 1

    image_key = argv[0]
    model_name = "attention_unet_v1"
    wait = False
    i = 1
    while i < len(argv):
        if argv[i] == "--model":
            model_name = argv[i + 1]
            i += 2
        elif argv[i] == "--wait":
            wait = True
            i += 1
        else:
            i += 1

    job_id = f"smoke-{uuid.uuid4()}"
    print(f"\n쪽지 보내는 중…")
    print(f"  job_id     : {job_id}")
    print(f"  image_key  : {image_key}")
    print(f"  model_name : {model_name}")
    print(f"  conformal_q: {CONFORMAL_Q}")

    result = app.send_task(
        "analysis.run_job",
        kwargs={
            "job_id": job_id,
            "image_key": image_key,
            "model_name": model_name,
            "model_version_id": None,
            "conformal_q": CONFORMAL_Q,
        },
        queue="gpu",
    )
    print(f"\n보냄 — task id = {result.id}")

    if not wait:
        print("우체부 창(celery worker)의 로그를 확인하세요.")
        print("결과까지 여기서 기다리려면 --wait 을 붙여서 다시 실행하면 됩니다.\n")
        return 0

    # ⚠️ --wait은 result_backend가 설정돼 있어야 동작한다. 지금 celery_app.py는
    #    broker만 설정하고 backend는 없으므로, 없으면 안내만 하고 끝낸다
    #    (여기서 예외로 죽으면 "쪽지는 잘 갔는데 스크립트가 실패한" 걸로 보인다).
    if not app.conf.result_backend:
        print("\n⚠️ result_backend가 설정돼 있지 않아 결과를 여기서 못 받습니다.")
        print("   워커 창 로그로 확인하세요 (정상 동작이며 오류가 아닙니다).\n")
        return 0

    print("\n결과 기다리는 중… (세그멘테이션 20회 + 리포트 생성, 1~2분)")
    try:
        stats = result.get(timeout=600)
    except Exception as exc:  # noqa: BLE001 — 실패해도 사유를 보여주고 끝낸다
        print(f"\n❌ 실패: {type(exc).__name__}: {exc}\n")
        return 1

    print("\n" + "=" * 58)
    print(f"  sTIL      : {stats.get('stil_value')}%")
    print(f"  예측구간   : {stats.get('lower')} ~ {stats.get('upper')}%")
    print(f"  판정      : {stats.get('decision')}")
    print(f"  구성비     : {stats.get('class_composition')}")
    print(f"  마스크     : {stats.get('mask_key')}")
    report = stats.get("medgemma_report") or {}
    print(f"  리포트 생성: {'실패' if report.get('generation_failed') else '성공'}")
    print("=" * 58 + "\n")

    if stats.get("class_composition", {}).get("immune") == 0.0:
        print("⚠️ immune 0% — 괴사가 많은 타일일 가능성. 시연용으로는 다른 이미지를 권장.\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
