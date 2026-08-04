import type { EmploymentStatus, Invitation, Role, Staff } from '@/api/types';

export const ROLE_LABEL : Record<Role, string> = {
    doctor: '의사',
    nurse: '간호사',
    admin: '관리자',
};

export const EMPLOYMENT_LABEL : Record<EmploymentStatus, string> = {
    active: '재직',
    leave: '휴직',
    resigned: '퇴사',
};

// staffBrief >> 아이디 · 소속
export const staffBrief = (s : Staff) : string =>
    `${s.username} · ${s.department || '소속 미지정'}`;

export type InvitationState = 'live' | 'used' | 'expired';

export const INVITATION_STATE_LABEL : Record<InvitationState, string> = {
    live: '사용 가능',
    used: '사용됨',
    expired: '만료',
};

// 사용됨 > 만료 > 사용 가능
export const invitationState = (i : Invitation) : InvitationState => {
    if (i.is_used) return 'used';
    if (new Date(i.expires_at) <= new Date()) return 'expired';
    return 'live';
};
