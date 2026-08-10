import type { AccountRequestStatus, Role, Staff } from '@/api/types';

export const ROLE_LABEL : Record<Role, string> = {
    doctor: '의사',
    nurse: '간호사',
    admin: '관리자',
};

// staffBrief >> 아이디 · 소속
export const staffBrief = (s : Staff) : string =>
    `${s.username} · ${s.department || '소속 미지정'}`;

export const REQUEST_STATUS_LABEL : Record<AccountRequestStatus, string> = {
    pending: '대기',
    approved: '승인',
    rejected: '거절',
};
