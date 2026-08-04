import type {Batch} from "@/api/types";
import { PATIENT_1, PATIENT_2, PATIENT_3 } from './patients';
import { ME } from './staff';

const STAFF_ID = ME.id;

export const mockBatches: Batch[] = [
    {
        id: '3f8a1c20-9d4e-4b71-8a02-1e5c7d930001',
        patient: PATIENT_1.id,
        patient_summary: PATIENT_1,
        status: 'pending',
        created_by: STAFF_ID,
        created_at: '2026-08-03T09:12:03.412000+09:00',
        updated_at: '2026-08-03T09:12:03.412000+09:00',
    },
    {
        id: '3f8a1c20-9d4e-4b71-8a02-1e5c7d930002',
        patient: PATIENT_2.id,
        patient_summary: PATIENT_2,
        status: 'processing',
        created_by: STAFF_ID,
        created_at: '2026-08-03T10:04:18.220000+09:00',
        updated_at: '2026-08-03T10:19:47.006000+09:00',
    },
    {
        id: '3f8a1c20-9d4e-4b71-8a02-1e5c7d930003',
        patient: PATIENT_3.id,
        patient_summary: PATIENT_3,
        status: 'done',
        created_by: STAFF_ID,
        created_at: '2026-08-02T14:31:07.905000+09:00',
        updated_at: '2026-08-02T15:08:52.418000+09:00',
    },
    {
        // 환자 미연결
        id: '3f8a1c20-9d4e-4b71-8a02-1e5c7d930004',
        patient: null,
        patient_summary: null,
        status: 'failed',
        created_by: STAFF_ID,
        created_at: '2026-08-01T16:47:52.113000+09:00',
        updated_at: '2026-08-01T16:49:10.882000+09:00',
    },
];
