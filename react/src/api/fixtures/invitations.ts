import type { Invitation } from '@/api/types';

// 17 초대코드 가입에서 입력해볼 코드
export const mockInvitations : Invitation[] = [
    {
        code: 'K7M2QX9A',
        role: 'doctor',
        department: '병리과',
        expires_at: '2026-08-11T23:59:59.000000+09:00',
        is_used: false,
        created_at: '2026-08-04T09:00:00.000000+09:00',
    },
    {
        code: 'R4B8TN1C',
        role: 'nurse',
        department: '유방외과',
        expires_at: '2026-08-09T23:59:59.000000+09:00',
        is_used: false,
        created_at: '2026-08-02T09:00:00.000000+09:00',
    },
    {
        // 만료
        code: 'Z1Y5WD3E',
        role: 'doctor',
        department: '종양내과',
        expires_at: '2026-07-20T23:59:59.000000+09:00',
        is_used: false,
        created_at: '2026-07-13T09:00:00.000000+09:00',
    },
    {
        // 사용됨
        code: 'Q6P0LF7G',
        role: 'nurse',
        department: '병리과',
        expires_at: '2026-08-15T23:59:59.000000+09:00',
        is_used: true,
        created_at: '2026-08-01T09:00:00.000000+09:00',
    },
];
