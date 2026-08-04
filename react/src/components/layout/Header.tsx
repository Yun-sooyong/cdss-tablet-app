import { Link, useNavigate } from 'react-router-dom';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Bell, LogOut } from 'lucide-react';

import { getMe, getNotifications, logout } from '@/api';
import { qk } from '@/api/keys';
import { ThemeToggle } from '@/components/ThemeToggle';
import { UploadIndicator } from '@/components/upload/UploadIndicator';
import { cn } from '@/lib/utils';
import Breadcrumb from './Breadcrumb';
import { CONTAINER } from './container';

// base >> 링크 접두사. 관리 콘솔은 '/admin'
export default function Header({
    base = '',
    tone = 'brand',
} : {
    base? : string;
    tone? : 'brand' | 'admin';
}) {
    const navigate = useNavigate();
    const queryClient = useQueryClient();

    const { data: me } = useQuery({ queryKey: qk.me, queryFn: getMe });
    const { data: notifications } = useQuery({
        queryKey: qk.notifications,
        queryFn: getNotifications,
    });

    const unread = notifications?.filter((n) => !n.is_read).length ?? 0;

    async function signOut() {
        await logout();
        queryClient.clear();
        navigate('/login', { replace: true });
    }

    return (
        <header
            className={cn(
                'h-14 shrink-0 border-b border-border',
                tone === 'admin' ? 'bg-admin-soft' : 'bg-surface',
            )}
        >
            <div className={`${CONTAINER} flex h-full items-center justify-between gap-4 px-6`}>
                <Breadcrumb />

                <div className="flex shrink-0 items-center gap-3">
                    <UploadIndicator />

                    <ThemeToggle />

                    {/* 알림 >> 미읽음 배지 */}
                    <Link
                        to={`${base}/notifications`}
                        aria-label={unread > 0 ? `알림 ${unread}건` : '알림'}
                        className="relative text-ink-muted transition-colors hover:text-ink"
                    >
                        <Bell size={16} />
                        {unread > 0 && (
                            <span className="absolute -right-1.5 -top-1.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-brand px-1 text-[10px] font-semibold tabular-nums text-on-brand">
                                {unread > 99 ? '99+' : unread}
                            </span>
                        )}
                    </Link>

                    <Link
                        to={`${base}/profile`}
                        className="text-sm text-ink transition-colors hover:text-brand"
                    >
                        {me?.username ?? '-'}
                    </Link>

                    <button
                        type="button"
                        onClick={signOut}
                        aria-label="로그아웃"
                        className="text-ink-muted transition-colors hover:text-ink"
                    >
                        <LogOut size={15} />
                    </button>
                </div>
            </div>
        </header>
    );
}
