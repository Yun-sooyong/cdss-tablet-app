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


def fake_server_response(masks: np.ndarray, declared_mc_samples: int = None) -> MagicMock:
    resp = MagicMock()
    resp.raise_for_status.return_value = None
    resp.content = msgpack.packb({
        "job_id": "job-1",
        "model_name_used": "unet_v1",
        "mc_samples": declared_mc_samples if declared_mc_samples is not None else masks.shape[0],
        "height": masks.shape[1],
        "width": masks.shape[2],
        "num_classes": 5,
        "masks": _pack_masks_like_real_server(masks),
    }, use_bin_type=True)
    return resp


def test_unpack_matches_real_server_packing():
    masks = np.zeros((20, 8, 8), dtype=np.uint8)
    masks[:, 4:, :] = 2
    resp = fake_server_response(masks)

    unpacked = _unpack_masks(resp.content)
    assert unpacked.shape == (20, 8, 8)
    assert unpacked.dtype == np.uint8
    assert (unpacked == masks).all()


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
        result = call_segmentation("uploads/x.png", "attention_unet_v1", job_id="job-9")

    args, kwargs = mock_post.call_args
    body = msgpack.unpackb(kwargs["data"], raw=False)
    assert body["gcs_image_path"] == "gs://test-bucket/uploads/x.png"
    assert body["job_id"] == "job-9"
    assert result.shape == (20, 8, 8)


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
    print(f"\n{len(fns) - failed}/{len(fns)} passed")
    sys.exit(1 if failed else 0)
