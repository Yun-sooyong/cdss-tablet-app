import type { Staff } from '@/api/types';

// ME >> batches.ts의 created_by
export const mockStaff : Staff[] = [
    {
        id: 'e2c7a940-3b18-4d6f-a052-7f9c1e8b4a33',
        username: 'doctor1',
        email: 'doctor1@hosp.example',
        role: 'doctor',
        department: '병리과',
        employment_status: 'active',
        resigned_at: null,
        created_at: '2026-03-02T09:00:00.000000+09:00',
    },
    {
        id: 'e2c7a940-3b18-4d6f-a052-7f9c1e8b4a34',
        username: 'doctor2',
        email: 'doctor2@hosp.example',
        role: 'doctor',
        department: '종양내과',
        employment_status: 'active',
        resigned_at: null,
        created_at: '2026-03-02T09:00:00.000000+09:00',
    },
    {
        id: 'e2c7a940-3b18-4d6f-a052-7f9c1e8b4a35',
        username: 'nurse1',
        email: 'nurse1@hosp.example',
        role: 'nurse',
        department: '유방외과',
        employment_status: 'active',
        resigned_at: null,
        created_at: '2026-04-13T09:00:00.000000+09:00',
    },
    {
        id: 'e2c7a940-3b18-4d6f-a052-7f9c1e8b4a36',
        username: 'admin1',
        email: 'admin1@hosp.example',
        role: 'admin',
        department: '정보전략팀',
        employment_status: 'active',
        resigned_at: null,
        created_at: '2026-01-05T09:00:00.000000+09:00',
    },
    {
        id: 'e2c7a940-3b18-4d6f-a052-7f9c1e8b4a37',
        username: 'doctor3',
        email: 'doctor3@hosp.example',
        role: 'doctor',
        department: '영상의학과',
        employment_status: 'leave',
        resigned_at: null,
        created_at: '2026-02-17T09:00:00.000000+09:00',
    },
    {
        // 퇴사
        id: 'e2c7a940-3b18-4d6f-a052-7f9c1e8b4a38',
        username: 'nurse2',
        email: 'nurse2@hosp.example',
        role: 'nurse',
        department: '병리과',
        employment_status: 'resigned',
        resigned_at: '2026-06-30',
        created_at: '2025-11-11T09:00:00.000000+09:00',
    },
];

export const [ME, STAFF_DOCTOR2, STAFF_NURSE1, STAFF_ADMIN1] = mockStaff;
