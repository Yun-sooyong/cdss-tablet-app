"""Mosec 세그멘테이션 서버 호출 — 학원 컴퓨터에서 로컬로 돌아가는 실제 서버.

이전 프로젝트의 실제 배포 소스(server.py, inference.py, model_registry.py)를
직접 확인하고 맞췄다 (2026-08-03).

⚠️ 로컬(학원 컴퓨터)에서만 접근한다는 전제로 Cloud Run 때 쓰던 ID 토큰 인증은
   뺐다. 외부에 노출하게 되면 인증을 다시 추가해야 한다.

✅ 해결됨 — model_name vs model_version_id (2026-08-03, 정다희 반영):
   Mosec은 "unet_v1"/"attention_unet_v1" 같은 이름 문자열로 모델을 찾는데
   (model_registry.py), 예전엔 Django가 model_version_id(UUID)만 넘겨줘서
   이름을 알 수 없었다. 모르는 이름이 오면 Mosec은 에러 없이 조용히 unet_v1로
   폴백하기 때문에(model_registry.resolve()), 항상 기본 모델만 쓰이는데도
   아무 에러가 안 나는 위험한 상태였다.
   -> 태스크 kwargs에 model_name을 추가해달라고 요청했고 반영됐다. 지금은
      tasks.py가 `model_name or model_version_id` 순으로 골라서 넘긴다.
"""
import io
import os

import msgpack
import numpy as np

MOSEC_URL = os.environ.get("MOSEC_URL", "http://localhost:8000")

# 2026-08-05: 30분(1800초)에서 10분으로 줄였다.
# 워커는 --pool=solo라 한 번에 하나만 처리하므로, Mosec이 완전히 먹통이 되면
# 이 시간만큼 워커 전체가 통째로 멈춰서 뒤에 쌓인 작업도 손을 못 댄다.
# Mosec 서버 자체의 타임아웃이 5분(MOSEC_TIMEOUT=300000)이라 정상적인 경우엔
# 그 전에 응답이 오므로, 10분이면 넉넉하면서도 먹통일 때 빨리 포기할 수 있다.
REQUEST_TIMEOUT = int(os.environ.get("SEGMENTATION_TIMEOUT", "600"))

# MedGemma는 세그멘테이션과 성격이 달라 타임아웃을 따로 둔다 (2026-08-05).
# 실측 9초 안팎이라 120초면 넉넉하다. 세그멘테이션과 같은 10분을 쓰면,
# 생성이 멈췄을 때 --pool=solo 워커가 10분간 통째로 묶인다.
# 리포트 생성 실패는 치명적이지 않다(수치·판정은 이미 전달됨) — 오래 붙잡고
# 있는 것보다 빨리 포기하고 넘어가는 편이 낫다.
MEDGEMMA_TIMEOUT = int(os.environ.get("MEDGEMMA_TIMEOUT", "120"))

GCS_BUCKET = os.environ.get("GCS_BUCKET", "")


def _raise_for_status(resp, what: str) -> None:
    """실패 응답이면 **서버가 보낸 사유까지 담아서** 예외를 던진다.

    🔴 2026-08-05 — 원래는 resp.raise_for_status()를 그냥 불렀는데, 그러면
       "422 Client Error: Unprocessable Entity" 한 줄만 남고 Mosec이 친절하게
       적어 보낸 진짜 사유("GCS에서 이미지를 읽지 못함: 404 ...")가 통째로
       버려졌다. 원인을 찾으려면 매번 따로 요청을 다시 보내봐야 했다.

    ⚠️ 예외 타입(HTTPError)과 response는 그대로 유지한다 — pipeline/errors.py의
       friendly_error()가 status_code를 보고 한국어 안내를 고르기 때문이다.
    """
    import requests

    if resp.status_code < 400:
        return
    detail = (resp.text or "").strip()
    if len(detail) > 500:
        detail = detail[:500] + " …(생략)"
    message = f"Mosec {what} 실패 ({resp.status_code})"
    if detail:
        message += f": {detail}"
    raise requests.exceptions.HTTPError(message, response=resp)


def _unpack_masks(resp_bytes: bytes):
    """서버 응답(msgpack) -> ((N, H, W) uint8 마스크, mask_key).

    실제 서버(inference.py의 pack_masks)가 항상 "masks"라는 키로 npz를
    압축한다는 걸 소스로 확인했으므로, 이전처럼 여러 키 이름을 추측할
    필요가 없다.

    ⚠️ 2026-08-05: 서버가 mask_key(프론트엔드 오버레이용 색칠된 PNG의 GCS
       경로)도 같이 보내주기 시작해서 반환값이 튜플로 바뀌었다 — GCS 쓰기
       권한이 아직 없으면 서버가 None을 보낼 수 있다(정상, 에러 아님).
    """
    resp = msgpack.unpackb(resp_bytes, raw=False)
    with np.load(io.BytesIO(resp["masks"])) as npz:
        masks = npz["masks"]

    declared = resp.get("mc_samples")
    if declared is not None and declared != masks.shape[0]:
        raise ValueError(
            f"응답의 mc_samples({declared})와 실제 배열 회차 수({masks.shape[0]})가 다릅니다. "
            f"q=19.63은 20회 기준으로 보정된 값이라 회차가 다르면 커버리지가 깨집니다."
        )
    return masks.astype(np.uint8, copy=False), resp.get("mask_key"), resp.get("model_name_used")


def call_segmentation(image_key: str, model_version_id: str, job_id: str = ""):
    """Mosec 서버(/inference)에 GCS 경로를 넘겨 MC-Dropout 마스크 스택을 받는다.

    Mosec이 GCS를 직접 읽으므로(inference.py의 download_gcs_bytes) 워커가
    이미지를 따로 다운로드할 필요가 없다 — image_key를 gcs_image_path
    문자열로 바꿔서 넘기기만 하면 된다.

    Returns:
        (mc_stack, mask_key) — mask_key는 프론트엔드 오버레이용 색칠된 마스크
        PNG의 GCS 오브젝트 경로(예: "masks/{job_id}.png"). 서버가 아직 업로드
        권한이 없으면 None일 수 있다.
    """
    import requests

    gcs_image_path = f"gs://{GCS_BUCKET}/{image_key}"

    body = msgpack.packb(
        {
            "job_id": job_id,
            "gcs_image_path": gcs_image_path,
            "model_name": model_version_id,  # ⚠️ 임시 — 파일 상단 경고 참고
        },
        use_bin_type=True,
    )
    resp = requests.post(
        f"{MOSEC_URL}/inference",
        data=body,
        headers={"Content-Type": "application/msgpack"},
        timeout=REQUEST_TIMEOUT,
    )
    _raise_for_status(resp, "세그멘테이션")
    mc_stack, mask_key, model_used = _unpack_masks(resp.content)

    # 🔴 조용한 모델 폴백 감지 (2026-08-05).
    #    Mosec의 model_registry.resolve()는 모르는 이름이 오면 에러 없이
    #    unet_v1로 폴백한다. 그런데 unet_v1에는 ONNX 가중치가 없어서
    #    DummyUNet(내용과 무관한 무늬를 뱉는 가짜 모델)이 서빙된다.
    #    즉 이름 한 글자만 틀려도 아무 경고 없이 "그럴듯한 형식의 쓰레기 수치"가
    #    끝까지 흘러가 의사 화면에 표시된다 — 조용히 틀리는 게 제일 위험하다.
    #    응답에 실려오는 model_name_used로 대조해서 여기서 끊는다.
    if model_used is not None and model_used != model_version_id:
        raise ValueError(
            f"요청한 모델('{model_version_id}')과 실제 사용된 모델('{model_used}')이 "
            f"다릅니다. Mosec에 그 이름이 등록되어 있지 않아 기본 모델로 대체된 것으로 "
            f"보입니다 — 결과를 신뢰할 수 없어 중단합니다."
        )
    return mc_stack, mask_key


def call_medgemma(image, system_prompt: str, user_text: str, job_id: str = "",
                   max_new_tokens: int = 500) -> str:
    """같은 Mosec 서버의 /medgemma 라우트를 호출해 MedGemma 생성 텍스트를 받는다.

    ⚠️ 프롬프트는 여기서 만들지 않는다 — 호출자(pipeline/medgemma_report.py)가
       완성해서 넘긴다. 할루시네이션 방지 제약이 그 프롬프트에 들어있다.

        요청  msgpack{job_id, system, text, image(PNG bytes), max_new_tokens}
        응답  msgpack{job_id, generated_text}
    """
    import requests

    buf = io.BytesIO()
    image.save(buf, format="PNG")

    body = msgpack.packb(
        {
            "job_id": job_id,
            "system": system_prompt,
            "text": user_text,
            "image": buf.getvalue(),
            "max_new_tokens": max_new_tokens,
        },
        use_bin_type=True,
    )
    resp = requests.post(
        f"{MOSEC_URL}/medgemma",
        data=body,
        headers={"Content-Type": "application/msgpack"},
        timeout=MEDGEMMA_TIMEOUT,
    )
    _raise_for_status(resp, "MedGemma 생성")
    return msgpack.unpackb(resp.content, raw=False)["generated_text"]
