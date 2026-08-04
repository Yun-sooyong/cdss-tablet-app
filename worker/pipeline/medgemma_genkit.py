"""MedGemma 판독 보고서 생성 — Genkit 구조 버전 (실험용, 아직 tasks.py에서 안 씀).

medgemma_report.py와 실제 네트워크 호출(clients/mosec.call_medgemma)·프롬프트
문구는 동일하게 재사용한다. 이 파일이 새로 하는 일은:

  1) 출력 형식을 Pydantic 스키마(ReportOutput)로 강제
     — medgemma_report.py의 수동 정규식 JSON 파싱을 Genkit의 구조화된 출력으로 대체
  2) Mosec의 /medgemma 라우트를 Genkit의 "커스텀 모델"로 등록
     — 호출부 입장에서는 Vertex AI 모델이든 자체 호스팅 모델이든 똑같은
       ai.generate() 인터페이스로 보인다
  3) @ai.flow()로 감싸서 흐름 하나로 추적 가능하게

⚠️ genkit 파이썬 패키지는 API가 자주 바뀐다. 아래 구조(모델 정의 → flow 정의 →
   output_schema로 생성)는 Genkit 개념 자체는 맞지만, 실제 설치된 버전에서
   클래스/메서드 이름이 다르면 `pip show genkit` 버전 확인 후 맞춰야 한다.

⚠️ 아직 tasks.py는 이 파일을 부르지 않는다 (medgemma_report.generate_report를
   계속 씀). 이 파일이 단독으로 검증되면, tasks.py의 import 한 줄만 바꾸면
   교체된다 — mosec_mock -> mosec 때와 같은 패턴.
"""
import asyncio
import base64
import io

from PIL import Image
from pydantic import BaseModel, Field

from genkit.ai import Genkit
from genkit.types import GenerateRequest, GenerateResponse, Message, Role, TextPart

from clients.mosec import call_medgemma
from pipeline.medgemma_report import (
    DISCLAIMER,
    SYSTEM_PROMPT,
    _build_user_text,
    _build_visualization,
)

ai = Genkit()


class ReportOutput(BaseModel):
    """MedGemma가 채워야 하는 필드 — 이 스키마가 예전 SYSTEM_PROMPT의 JSON 형식
    지시문을 대신한다. Genkit이 이 스키마에 맞게 파싱·검증까지 담당한다."""

    segmentation_summary: str = Field(
        description="첨부 이미지의 조직 유형별 구성을 1~2문장으로 요약"
    )
    findings: str = Field(
        description="sTIL 수치와 불확실성(기권 여부)을 고려한 임상 판독 소견"
    )


class ReportInput(BaseModel):
    """flow는 인자를 최대 1개(+context)만 받아서, stats/이미지/job_id를 객체
    하나로 묶어야 한다. Genkit이 flow 입출력을 추적(tracing)하려고 JSON 직렬화를
    시도하므로, numpy 배열을 직접 넘기면 안 된다 — PNG를 base64 문자열로
    미리 인코딩해서 넘긴다."""

    stats: dict
    image_png_b64: str
    job_id: str = ""


def _part_get(part, key):
    """content part가 TextPart 객체일 수도, 우리가 넣은 순수 dict({"media": ...})일
    수도 있어서 둘 다 안전하게 읽는다.

    Genkit이 파싱한 뒤에는 Part(root=TextPart(...)) 처럼 discriminated union
    래퍼(root)로 한 겹 더 감싸므로, 있으면 벗겨내고 실제 값을 본다."""
    if isinstance(part, dict):
        return part.get(key)
    root = getattr(part, "root", None)
    if root is not None:
        part = root
    return getattr(part, key, None)


async def mosec_medgemma_model(request: GenerateRequest) -> GenerateResponse:
    """Mosec 서버의 /medgemma 라우트를 Genkit이 인식하는 '모델'로 등록.

    ⚠️ 실제 HTTP 호출은 clients/mosec.call_medgemma()를 그대로 재사용한다 —
       여기서 네트워크 코드를 새로 짜지 않는다 (이미 실측 검증된 부분).
    ⚠️ 이미지는 PIL 객체가 아니라 base64 data URI(문자열)로 실려온다 — Genkit이
       이 요청 자체도 추적(tracing)하려고 JSON 직렬화를 시도하기 때문에,
       여기 도착하기 전까지는 계속 문자열 상태여야 한다.
    """
    system_text = ""
    user_text = ""
    image = None

    for message in request.messages:
        for part in message.content:
            text = _part_get(part, "text")
            if text and message.role == Role.SYSTEM:
                system_text = text
            elif text:
                user_text = text
            media = _part_get(part, "media")
            if media is not None:
                url = media.get("url") if isinstance(media, dict) else _part_get(media, "url")
                if url and url.startswith("data:"):
                    b64_data = url.split(",", 1)[1]
                    image = Image.open(io.BytesIO(base64.b64decode(b64_data)))

    generated_text = call_medgemma(image, system_text, user_text)
    return GenerateResponse(
        message=Message(role=Role.MODEL, content=[TextPart(text=generated_text)])
    )


ai.define_model(name="mosec/medgemma", fn=mosec_medgemma_model)


@ai.flow()
async def generate_report_flow(input: ReportInput) -> ReportOutput:
    """sTIL/conformal 결과 + 세그멘테이션 마스크 -> 구조화된 판독 보고서.

    medgemma_report.generate_report()의 재시도 루프 대신, output_schema로
    스키마를 강제해서 Genkit이 파싱 실패 시 알아서 처리하게 맡긴다.
    """
    user_text = _build_user_text(input.stats)
    image_data_uri = f"data:image/png;base64,{input.image_png_b64}"

    response = await ai.generate(
        model="mosec/medgemma",
        messages=[
            Message(role=Role.SYSTEM, content=[TextPart(text=SYSTEM_PROMPT)]),
            Message(
                role=Role.USER,
                content=[TextPart(text=user_text), {"media": {"url": image_data_uri}}],
            ),
        ],
        output_schema=ReportOutput,
    )
    return response.output


def generate_report(stats: dict, mc_stack, job_id: str = "") -> dict:
    """tasks.py가 부르는 기존 medgemma_report.generate_report()와 동일한
    시그니처/반환 모양을 유지하는 래퍼 — 검증되면 import 한 줄만 바꿔서 교체."""
    if stats.get("stil_value") is None:
        return {
            "segmentation_summary": "",
            "findings": "sTIL 계산 불가로 판독 보고서를 생성하지 않았습니다.",
            "disclaimer": DISCLAIMER,
            "generation_failed": True,
        }

    try:
        image = _build_visualization(mc_stack)
        buf = io.BytesIO()
        image.save(buf, format="PNG")
        image_png_b64 = base64.b64encode(buf.getvalue()).decode("ascii")

        result = asyncio.run(
            generate_report_flow(
                ReportInput(stats=stats, image_png_b64=image_png_b64, job_id=job_id)
            )
        )
        # Genkit 버전에 따라 ReportOutput 인스턴스가 아니라 순수 dict로 올 수도 있다.
        if isinstance(result, dict):
            summary = result.get("segmentation_summary", "")
            findings = result.get("findings", "")
        else:
            summary = result.segmentation_summary
            findings = result.findings
        return {
            "segmentation_summary": summary,
            "findings": findings,
            "disclaimer": DISCLAIMER,
            "generation_failed": False,
        }
    except Exception as exc:  # noqa: BLE001 — 실험용 경로, 실패 사유를 그대로 보고
        return {
            "segmentation_summary": "(자동 요약 생성 실패 — 수동 확인 필요)",
            "findings": f"(판독 소견 생성 실패: {exc})",
            "disclaimer": DISCLAIMER,
            "generation_failed": True,
        }
