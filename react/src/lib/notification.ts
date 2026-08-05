import type { AppNotification, NotificationType } from '@/api/types';

export type NotificationScope = 'clinical' | 'admin';

// CLINICAL >> 판독 콘솔이 받는 알림. 관리 콘솔은 이 밖의 것만 받는다
const CLINICAL : readonly string[] = [
    'analysis_done',
    'share',
    'chat',
] satisfies readonly NotificationType[];

export const inScope = (notification : AppNotification, scope : NotificationScope) : boolean =>
    scope === 'admin'
        ? !CLINICAL.includes(notification.type)
        : CLINICAL.includes(notification.type);

export const unreadIn = (
    notifications : AppNotification[] | undefined,
    scope : NotificationScope,
) : number => (notifications ?? []).filter((n) => !n.is_read && inScope(n, scope)).length;