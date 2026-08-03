"""가짜 현미경 — 실제 Mosec 서버 없이 파이프라인을 테스트하기 위한 목(mock) 클라이언트.

USE_MOCK_INFERENCE=true 일 때 mosec.py 대신 이 파일이 쓰인다.
함수 이름(call_segmentation)과 반환 모양을 mosec.py와 똑같이 맞춰서,
나중에 진짜 서버로 바꿀 때 import 한 줄만 바꾸면 되게 만든다.
"""
import numpy as np

CLASS_TUMOR, CLASS_STROMA, CLASS_IMMUNE, CLASS_NECROSIS, CLASS_OTHER = range(5)


def call_segmentation(image_key: str, model_version_id: str, job_id: str = "") -> np.ndarray:
    """실제 call_segmentation()과 이름·반환 모양을 맞춘 가짜 함수.

    MC Dropout 20회를 흉내내되, 항상 같은 가짜 결과를 돌려준다.
    위쪽 절반은 stroma, 아래쪽 절반은 immune으로 고정해서
    sTIL 계산 결과가 항상 50%로 예측 가능하게 만들어 검증을 쉽게 한다.
    """
    n_pass, height, width = 20, 64, 64
    mc_stack = np.full((n_pass, height, width), CLASS_STROMA, dtype=np.uint8)
    mc_stack[:, height // 2:, :] = CLASS_IMMUNE
    return mc_stack
