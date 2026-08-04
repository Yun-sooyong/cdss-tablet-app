import type { ModelVersion } from '@/api/types';

// name >> 워커 레지스트리 키 : model_registry.py
export const mockModelVersions: ModelVersion[] = [
    {
        id: 'd94e2b17-6f80-4a3c-9e51-8c0b5d7e0001',
        name: 'attention_unet_v1',
        version: 'v1',
        conformal_q: 19.629,
        is_active: true,
        created_at: '2026-07-14T11:20:41.108000+09:00',
    },
    {
        id: 'd94e2b17-6f80-4a3c-9e51-8c0b5d7e0002',
        name: 'attention_unet_v2',
        version: 'v2',
        conformal_q: 17.412,
        is_active: true,
        created_at: '2026-07-28T16:05:12.774000+09:00',
    },
    {
        id: 'd94e2b17-6f80-4a3c-9e51-8c0b5d7e0003',
        name: 'unet_v1',
        version: 'v1',
        conformal_q: 22.084,
        is_active: true,
        created_at: '2026-06-30T09:47:33.512000+09:00',
    },
    {
        id: 'd94e2b17-6f80-4a3c-9e51-8c0b5d7e0004',
        name: 'fpn_v1',
        version: 'v1',
        conformal_q: 24.503,
        is_active: false,
        created_at: '2026-06-11T13:52:08.331000+09:00',
    },
];
