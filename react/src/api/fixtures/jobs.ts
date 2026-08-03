import type { Job } from '@/api/types';

const MV1 = 'd94e2b17-6f80-4a3c-9e51-8c0b5d7e0001';
const MV2 = 'd94e2b17-6f80-4a3c-9e51-8c0b5d7e0002';
const MV3 = 'd94e2b17-6f80-4a3c-9e51-8c0b5d7e0003';

const IMG = (n: number) =>
    `7c2b4e91-5a63-4d08-9f14-2b8e6a1c${String(n).padStart(4, '0')}`;
const JOB = (n: number) =>
    `a51d6f38-4c72-4e95-b063-9d7f2a4b${String(n).padStart(4, '0')}`;

export const mockJobs: Job[] = [
    // 상태용 4개 >> 05 처리중, 10 오류
    {
        // queued >> 아직 시작 전
        id: JOB(1),
        image: IMG(1),
        model_version: MV1,
        status: 'queued',
        result: null,
        error_message: '',
        started_at: null,
        finished_at: null,
        created_at: '2026-08-03T09:12:05.003000+09:00',
    },
    {
        // running >> 추론 중
        id: JOB(2),
        image: IMG(2),
        model_version: MV1,
        status: 'running',
        result: null,
        error_message: '',
        started_at: '2026-08-03T10:05:02.771000+09:00',
        finished_at: null,
        created_at: '2026-08-03T10:04:20.115000+09:00',
    },
    {
        // stil_done >> 1차 콜백만 도착. medgemma_report 없음, finished_at null
        id: JOB(3),
        image: IMG(3),
        model_version: MV1,
        status: 'stil_done',
        result: {
            stil_value: 33.5,
            sigma: 5.1,
            lower: 23.3,
            upper: 43.7,
            abstain: false,
            decision: 'LOW',
            cp_value: 0.86,
            n_valid: 134,
            class_composition: {
                tumor: 47.2, stroma: 24.8, immune: 12.5, necrosis: 9.8, other: 5.7,
            },
        },
        error_message: '',
        started_at: '2026-08-03T10:05:03.442000+09:00',
        finished_at: null,
        created_at: '2026-08-03T10:04:20.882000+09:00',
    },

    // 09용 6개 >> 판정 유보 검증함
    {
        // 1 LOW >> 구간이 컷오프 아래
        id: JOB(4),
        image: IMG(4),
        model_version: MV1,
        status: 'succeeded',
        result: {
            stil_value: 12.4,
            sigma: 3.1,
            lower: 6.2,
            upper: 18.6,
            abstain: false,
            decision: 'LOW',
            cp_value: 0.89,
            n_valid: 168,
            class_composition: {
                tumor: 52.3, stroma: 30.1, immune: 4.3, necrosis: 8.1, other: 5.2,
            },
            medgemma_report: {
                summary:
                    '종양 영역이 우세하며 기질 내 림프구 침윤이 제한적으로 관찰됩니다. sTIL 12.4%로 낮은 수준입니다.',
                generation_failed: false,
            },
        },
        error_message: '',
        started_at: '2026-08-02T14:33:12.008000+09:00',
        finished_at: '2026-08-02T14:41:55.331000+09:00',
        created_at: '2026-08-02T14:31:12.440000+09:00',
    },
    {
        // 2 HIGH >> 구간이 컷오프 위
        id: JOB(5),
        image: IMG(5),
        model_version: MV1,
        status: 'succeeded',
        result: {
            stil_value: 71.8,
            sigma: 4.5,
            lower: 62.8,
            upper: 80.8,
            abstain: false,
            decision: 'HIGH',
            cp_value: 0.91,
            n_valid: 142,
            class_composition: {
                tumor: 48.5, stroma: 10.2, immune: 26.0, necrosis: 9.3, other: 6.0,
            },
            medgemma_report: {
                summary:
                    '기질 영역 전반에 걸쳐 림프구 침윤이 뚜렷합니다. sTIL 71.8%로 높은 수준입니다.',
                generation_failed: false,
            },
        },
        error_message: '',
        started_at: '2026-08-02T14:34:20.517000+09:00',
        finished_at: '2026-08-02T14:43:07.995000+09:00',
        created_at: '2026-08-02T14:31:13.101000+09:00',
    },
    {
        // 3 ABSTAIN >> 좁게 가로지름
        id: JOB(6),
        image: IMG(6),
        model_version: MV2,
        status: 'succeeded',
        result: {
            stil_value: 48.9,
            sigma: 3.2,
            lower: 42.5,
            upper: 55.3,
            abstain: true,
            decision: 'ABSTAIN',
            cp_value: 0.87,
            n_valid: 155,
            class_composition: {
                tumor: 50.1, stroma: 18.4, immune: 17.6, necrosis: 8.7, other: 5.2,
            },
            medgemma_report: {
                summary:
                    '예측 구간이 임상 컷오프를 포함하여 자동 판정을 유보했습니다. 병리 전문의 확인이 필요합니다.',
                generation_failed: false,
            },
        },
        error_message: '',
        started_at: '2026-08-02T14:35:41.229000+09:00',
        finished_at: '2026-08-02T14:44:18.663000+09:00',
        created_at: '2026-08-02T14:31:13.775000+09:00',
    },
    {
        // 4 ABSTAIN >> sigma 커서 구간 매우 넓음
        id: JOB(7),
        image: IMG(7),
        model_version: MV2,
        status: 'succeeded',
        result: {
            stil_value: 52.0,
            sigma: 12.4,
            lower: 27.2,
            upper: 76.8,
            abstain: true,
            decision: 'ABSTAIN',
            cp_value: 0.85,
            n_valid: 103,
            class_composition: {
                tumor: 55.3, stroma: 14.4, immune: 15.6, necrosis: 9.1, other: 5.6,
            },
            medgemma_report: {
                summary:
                    '타일 간 예측 편차가 커 불확실성이 높습니다(σ 12.4). 구간 폭이 넓어 판정을 유보했습니다.',
                generation_failed: false,
            },
        },
        error_message: '',
        started_at: '2026-08-02T14:36:55.842000+09:00',
        finished_at: '2026-08-02T14:46:02.117000+09:00',
        created_at: '2026-08-02T14:31:14.398000+09:00',
    },
    {
        // 5 하한 클리핑 >> lower가 0 미만
        id: JOB(8),
        image: IMG(8),
        model_version: MV3,
        status: 'succeeded',
        result: {
            stil_value: 4.2,
            sigma: 6.0,
            lower: -7.8,
            upper: 16.2,
            abstain: false,
            decision: 'LOW',
            cp_value: 0.88,
            n_valid: 121,
            class_composition: {
                tumor: 46.9, stroma: 34.2, immune: 1.5, necrosis: 11.3, other: 6.1,
            },
            medgemma_report: {
                summary: '',
                generation_failed: true,
            },
        },
        error_message: '',
        started_at: '2026-08-02T14:38:10.334000+09:00',
        finished_at: '2026-08-02T14:47:29.750000+09:00',
        created_at: '2026-08-02T14:31:15.062000+09:00',
    },
    {
        // 6 상한 클리핑 >> upper가 100 초과
        id: JOB(9),
        image: IMG(9),
        model_version: MV3,
        status: 'succeeded',
        result: {
            stil_value: 94.6,
            sigma: 7.2,
            lower: 80.2,
            upper: 109.0,
            abstain: false,
            decision: 'HIGH',
            cp_value: 0.92,
            n_valid: 187,
            class_composition: {
                tumor: 52.4, stroma: 1.6, immune: 28.0, necrosis: 12.0, other: 6.0,
            },
            medgemma_report: {
                summary:
                    '기질 대비 림프구 비율이 극단적으로 높습니다. 상한 구간이 100%를 초과해 실질 상한은 100%로 해석해야 합니다.',
                generation_failed: false,
            },
        },
        error_message: '',
        started_at: '2026-08-02T14:39:33.618000+09:00',
        finished_at: '2026-08-02T14:49:11.204000+09:00',
        created_at: '2026-08-02T14:31:15.688000+09:00',
    },

    // 실패 1개 >> 10 오류
    {
        id: JOB(10),
        image: IMG(10),
        model_version: MV3,
        status: 'failed',
        result: null,
        error_message:
            'Mosec 추론 서버 응답 없음 (타임아웃 600초). 타일 34/128에서 중단됨.',
        started_at: '2026-08-01T16:48:04.559000+09:00',
        finished_at: '2026-08-01T16:58:07.001000+09:00',
        created_at: '2026-08-01T16:47:54.220000+09:00',
    },
];
