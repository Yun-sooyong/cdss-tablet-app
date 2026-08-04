import type { AnalysisShare } from '@/api/types';
import { ME, STAFF_DOCTOR2, STAFF_NURSE1 } from './staff';

const BATCH_1 = '3f8a1c20-9d4e-4b71-8a02-1e5c7d930001';
const BATCH_2 = '3f8a1c20-9d4e-4b71-8a02-1e5c7d930002';
const BATCH_3 = '3f8a1c20-9d4e-4b71-8a02-1e5c7d930003';

export const mockShares : AnalysisShare[] = [
    {
        // 13 >> 남이 나에게 보낸 것
        id: 'b8d31f74-2a56-4c19-9e83-6f4a0d2b0001',
        batch: BATCH_1,
        shared_by: STAFF_DOCTOR2.id,
        shared_to: ME.id,
        permission: 'read',
        expires_at: null,
        revoked_at: null,
        created_at: '2026-08-02T11:24:07.115000+09:00',
    },
    {
        // 만료됨
        id: 'b8d31f74-2a56-4c19-9e83-6f4a0d2b0002',
        batch: BATCH_2,
        shared_by: STAFF_NURSE1.id,
        shared_to: ME.id,
        permission: 'comment',
        expires_at: '2026-08-03T23:59:59.000000+09:00',
        revoked_at: null,
        created_at: '2026-07-28T14:02:19.470000+09:00',
    },
    {
        // 12 >> 내가 보낸 것
        id: 'b8d31f74-2a56-4c19-9e83-6f4a0d2b0003',
        batch: BATCH_3,
        shared_by: ME.id,
        shared_to: STAFF_DOCTOR2.id,
        permission: 'read',
        expires_at: null,
        revoked_at: null,
        created_at: '2026-08-02T15:31:44.902000+09:00',
    },
    {
        // 회수됨
        id: 'b8d31f74-2a56-4c19-9e83-6f4a0d2b0004',
        batch: BATCH_3,
        shared_by: ME.id,
        shared_to: STAFF_NURSE1.id,
        permission: 'comment',
        expires_at: null,
        revoked_at: '2026-08-03T10:15:02.331000+09:00',
        created_at: '2026-08-02T15:32:10.554000+09:00',
    },
];
