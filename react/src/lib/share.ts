import type { AnalysisShare } from '@/api/types';

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
