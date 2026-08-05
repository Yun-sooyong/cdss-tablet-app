"""Mosec 세그멘테이션 서버 호출 — 학원 컴퓨터에서 로컬로 돌아가는 실제 서버.

이전 프로젝트의 실제 배포 소스(server.py, inference.py, model_registry.py)를
직접 확인하고 맞췄다 (2026-08-03).

⚠️ 로컬(학원 컴퓨터)에서만 접근한다는 전제로 Cloud Run 때 쓰던 ID 토큰 인증은
   뺐다. 외부에 노출하게 되면 인증을 다시 추가해야 한다.

⚠️ 알려진 계약 문제 — model_name vs model_version_id (미해결, 정다희 확인 필요):
   Mosec은 "unet_v1"/"attention_unet_v1" 같은 이름 문자열로 모델을 찾는다
   (model_registry.py). 그런데 Django가 태스크에 넣어주는 건 model_version_id
   (UUID)뿐이라 이름이 없다. 모르는 이름이 오면 Mosec은 에러 없이 조용히
   unet_v1로 폴백한다(model_registry.resolve()) — 즉 지금 이대로 연결하면
   항상 기본 모델만 쓰이는데 아무 에러도 안 남을 수 있다.
   -> TODO: 태스크 kwargs에 model_name(또는 ModelVersion.name)을 추가해달라고
      정다희님께 요청. 그 전까지는 model_version_id를 그대로 넘긴다(임시).
"""
import io
import os

import msgpack
import numpy as np

MOSEC_URL = os.environ.get("MOSEC_URL", "http://localhost:8000")
REQUEST_TIMEOUT = int(os.environ.get("SEGMENTATION_TIMEOUT", "1800"))
GCS_BUCKET = os.environ.get("GCS_BUCKET", "")


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
    return masks.astype(np.uint8, copy=False), resp.get("mask_key")


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
    resp.raise_for_status()
    return _unpack_masks(resp.content)


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
        timeout=REQUEST_TIMEOUT,
    )
    resp.raise_for_status()
    return msgpack.unpackb(resp.content, raw=False)["generated_text"]
