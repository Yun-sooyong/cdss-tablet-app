import type { AnalysisShare, SharePermission } from '@/api/types';

export const PERMISSION_LABEL : Record<SharePermission, string> = {
    read: '읽기',
    comment: '댓글',
};

export type ShareState = 'live' | 'expired' | 'revoked';

export const SHARE_STATE_LABEL : Record<ShareState, string> = {
    live: '유효',
    expired: '만료',
    revoked: '회수됨',
};

export const shareState = (share : AnalysisShare) : ShareState => {
    if (share.revoked_at) return 'revoked';
    if (share.expires_at && new Date(share.expires_at) <= new Date()) return 'expired';
    return 'live';
};
