import { Badge } from '@/components/ui/badge';

/* 상태 배지 >> 유효한 것만 또렷하게, 끝난 것은 흐리게.
   공유(유효·만료·회수)와 초대코드(사용 가능·사용됨·만료)가 같은 규칙을 쓴다 */
export function StateBadge({ label, live } : { label : string; live : boolean }) {
    return (
        <Badge
            variant="outline"
            className={live ? 'border-border text-ink-muted' : 'border-border text-ink-faint'}
        >
            {label}
        </Badge>
    );
}
