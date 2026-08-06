"""mosec.py 검증 — 실제 학원 서버 없이, 실제 서버 소스(server.py/inference.py)에서
확인한 응답 포장 방식을 그대로 흉내내서 언패킹 로직을 검증한다.
"""
import io
from unittest.mock import patch, MagicMock

import msgpack
import numpy as np

from clients.mosec import call_segmentation, _unpack_masks


def _pack_masks_like_real_server(masks: np.ndarray) -> bytes:
    """inference.py의 pack_masks()와 동일한 방식 — 키 이름 'masks'로 압축."""
    buf = io.BytesIO()
    np.savez_compressed(buf, masks=masks)
    return buf.getvalue()


def fake_server_response(masks: np.ndarray, declared_mc_samples: int = None,
                          mask_key: str = None,
                          model_name_used: str = "attention_unet_v1") -> MagicMock:
    resp = MagicMock()
    # 2026-08-05: mosec.py가 raise_for_status() 대신 _raise_for_status()를 쓰면서
    # status_code를 직접 본다 (서버가 보낸 실패 사유를 메시지에 담기 위해).
    # MagicMock 기본값은 숫자가 아니라 비교에서 터지므로 명시해준다.
    resp.status_code = 200
    resp.raise_for_status.return_value = None
    resp.content = msgpack.packb({
        "job_id": "job-1",
        "model_name_used": model_name_used,
        "mc_samples": declared_mc_samples if declared_mc_samples is not None else masks.shape[0],
        "height": masks.shape[1],
        "width": masks.shape[2],
        "num_classes": 5,
        "masks": _pack_masks_like_real_server(masks),
        "mask_key": mask_key,
    }, use_bin_type=True)
    return resp


def test_unpack_matches_real_server_packing():
    masks = np.zeros((20, 8, 8), dtype=np.uint8)
    masks[:, 4:, :] = 2
    resp = fake_server_response(masks)

    unpacked, mask_key, model_used = _unpack_masks(resp.content)
    assert unpacked.shape == (20, 8, 8)
    assert unpacked.dtype == np.uint8
    assert (unpacked == masks).all()
    assert mask_key is None  # 이 테스트에선 안 실었으니 None이 정상
    assert model_used == "attention_unet_v1"


def test_unpack_returns_mask_key_when_present():
    """서버가 마스크 PNG 업로드에 성공하면 mask_key가 같이 온다
    (2026-08-05, 프론트엔드 오버레이 기능 추가)."""
    masks = np.zeros((20, 8, 8), dtype=np.uint8)
    resp = fake_server_response(masks, mask_key="masks/job-1.png")

    _, mask_key, _ = _unpack_masks(resp.content)
    assert mask_key == "masks/job-1.png"


def test_mc_samples_mismatch_raises():
    masks = np.zeros((20, 8, 8), dtype=np.uint8)
    resp = fake_server_response(masks, declared_mc_samples=25)  # 실제 배열은 20인데 25라고 우김

    try:
        _unpack_masks(resp.content)
        assert False, "mc_samples 불일치를 못 잡음"
    except ValueError as e:
        assert "mc_samples" in str(e)


def test_call_segmentation_sends_gcs_path_and_model_name():
    masks = np.zeros((20, 8, 8), dtype=np.uint8)

    with patch("clients.mosec.GCS_BUCKET", "test-bucket"), \
         patch("requests.post", return_value=fake_server_response(masks)) as mock_post:
        mc_stack, mask_key = call_segmentation("uploads/x.png", "attention_unet_v1", job_id="job-9")

    args, kwargs = mock_post.call_args
    body = msgpack.unpackb(kwargs["data"], raw=False)
    assert body["gcs_image_path"] == "gs://test-bucket/uploads/x.png"
    assert body["job_id"] == "job-9"
    assert mc_stack.shape == (20, 8, 8)
    assert mask_key is None


def test_silent_model_fallback_is_detected():
    """🔴 Mosec은 모르는 모델 이름이 오면 에러 없이 unet_v1(=가중치 없는
    DummyUNet)로 폴백한다. 그대로 두면 '형식은 멀쩡한 쓰레기 수치'가 의사
    화면까지 흘러간다 — 조용히 틀리는 게 제일 위험하므로 여기서 끊어야 한다."""
    masks = np.zeros((20, 8, 8), dtype=np.uint8)
    resp = fake_server_response(masks, model_name_used="unet_v1")  # 폴백당한 상황

    with patch("clients.mosec.GCS_BUCKET", "test-bucket"), \
         patch("requests.post", return_value=resp):
        try:
            call_segmentation("uploads/x.png", "attention_unet_v1", job_id="job-9")
            assert False, "모델이 조용히 바뀌었는데 그대로 통과시킴"
        except ValueError as e:
            assert "attention_unet_v1" in str(e) and "unet_v1" in str(e), \
                "어떤 모델이 요청/사용됐는지가 메시지에 없으면 원인 파악이 어렵다"


def test_missing_model_name_used_does_not_break():
    """구버전 서버처럼 model_name_used를 안 실어보내면 검사를 건너뛴다
    (없는 정보로 잘못 막아서 정상 작업을 죽이면 안 된다)."""
    masks = np.zeros((20, 8, 8), dtype=np.uint8)
    resp = fake_server_response(masks, model_name_used=None)

    with patch("clients.mosec.GCS_BUCKET", "test-bucket"), \
         patch("requests.post", return_value=resp):
        mc_stack, _ = call_segmentation("uploads/x.png", "attention_unet_v1", job_id="job-9")
    assert mc_stack.shape == (20, 8, 8)


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
