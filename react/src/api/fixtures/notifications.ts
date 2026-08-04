import type { AppNotification } from '@/api/types';

const BATCH_3 = '3f8a1c20-9d4e-4b71-8a02-1e5c7d930003';
const BATCH_4 = '3f8a1c20-9d4e-4b71-8a02-1e5c7d930004';
const SHARE_1 = 'b8d31f74-2a56-4c19-9e83-6f4a0d2b0001';

// target_type >> 라우팅 기준
export const mockNotifications : AppNotification[] = [
    {
        id: 'c1e94a08-7b52-4d36-a071-3e8f5c9d0001',
        type: 'analysis_done',
        body: 'P9F2D0C31 · 박준호 분석이 완료되었습니다. 6건 중 확인 필요 2건.',
        target_type: 'batch',
        target_id: BATCH_3,
        is_read: false,
        created_at: '2026-08-02T15:08:52.418000+09:00',
    },
    {
        id: 'c1e94a08-7b52-4d36-a071-3e8f5c9d0002',
        type: 'share',
        body: 'doctor2 님이 케이스를 공유했습니다.',
        target_type: 'share',
        target_id: SHARE_1,
        is_read: false,
        created_at: '2026-08-02T11:24:07.115000+09:00',
    },
    {
        id: 'c1e94a08-7b52-4d36-a071-3e8f5c9d0003',
        type: 'analysis_done',
        body: '환자 미연결 배치 분석이 실패했습니다.',
        target_type: 'batch',
        target_id: BATCH_4,
        is_read: true,
        created_at: '2026-08-01T16:58:07.001000+09:00',
    },
    {
        id: 'c1e94a08-7b52-4d36-a071-3e8f5c9d0004',
        type: 'chat',
        body: 'nurse1 님이 메시지를 보냈습니다.',
        target_type: 'chat',
        target_id: null,
        is_read: true,
        created_at: '2026-07-31T09:41:33.882000+09:00',
    },
];
