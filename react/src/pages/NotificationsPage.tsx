// 11 알림
import { useNavigate } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { CircleCheck, MessageSquare, Share2 } from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import { toast } from 'sonner';

import { getNotifications, markAllNotificationsRead, markNotificationRead } from '@/api';
import { qk } from '@/api/keys';
import type { AppNotification, NotificationType } from '@/api/types';
import { Empty, Failed, Pending } from '@/components/QueryState';
import { formatRelative } from '@/lib/format';
import { cn } from '@/lib/utils';

const TYPE_ICON : Record<NotificationType, LucideIcon> = {
    analysis_done: CircleCheck,
    share: Share2,
    chat: MessageSquare,
};

// target_type >> 서버 문자열 → 경로.
// chat은 화면이 아직 없어 보내지 않는다. 읽음만 처리된다
const targetPath = (n : AppNotification) : string | null => {
    if (n.target_type === 'batch' && n.target_id) return `/batches/${n.target_id}`;
    if (n.target_type === 'share') return '/cases?from=shared';
    return null;
};

export default function NotificationsPage() {
    const navigate = useNavigate();
    const queryClient = useQueryClient();

    const { data, isPending, isError, error, refetch } = useQuery({
        queryKey: qk.notifications,
        queryFn: getNotifications,
    });

    const invalidate = () =>
        void queryClient.invalidateQueries({ queryKey: qk.notifications });

    const readOne = useMutation({
        mutationFn: (id : string) => markNotificationRead(id),
        onSuccess: invalidate,
        onError: (err : Error) =>
            toast.error('읽음 처리하지 못했습니다', { description: err.message }),
    });

    const readAll = useMutation({
        mutationFn: markAllNotificationsRead,
        onSuccess: invalidate,
        onError: (err : Error) =>
            toast.error('읽음 처리하지 못했습니다', { description: err.message }),
    });

    function open(n : AppNotification) {
        readOne.mutate(n.id);

        const path = targetPath(n);
        // 갈 곳이 없으면 클릭이 먹통으로 보인다. 읽음 처리했다고 알린다
        if (path) navigate(path);
        else toast.info('읽음으로 표시했습니다');
    }

    if (isPending) return <Pending />;
    if (isError) return <Failed error={error} onRetry={() => void refetch()} />;

    const unread = data.filter((n) => !n.is_read).length;

    return (
        <div className="max-w-3xl">
            {unread > 0 && (
                <div className="mb-4 flex justify-end">
                    <button
                        type="button"
                        onClick={() => readAll.mutate()}
                        disabled={readAll.isPending}
                        className="text-sm text-ink-muted transition-colors hover:text-ink disabled:opacity-40"
                    >
                        모두 읽음 ({unread})
                    </button>
                </div>
            )}

            {data.length === 0 ? (
                <Empty label="받은 알림이 없습니다." />
            ) : (
                <div className="divide-y divide-border border-y border-border">
                    {data.map((n) => {
                        const Icon = TYPE_ICON[n.type];

                        return (
                            <button
                                key={n.id}
                                type="button"
                                onClick={() => open(n)}
                                className="flex w-full items-start gap-3 py-4 text-left transition-colors hover:bg-brand-soft/50"
                            >
                                <Icon
                                    size={16}
                                    className={cn(
                                        'mt-0.5 shrink-0',
                                        n.is_read ? 'text-ink-faint' : 'text-brand',
                                    )}
                                />

                                <span className="min-w-0 flex-1">
                                    <span
                                        className={cn(
                                            'block text-[15px]',
                                            n.is_read ? 'text-ink-muted' : 'text-ink',
                                        )}
                                    >
                                        {n.body}
                                    </span>
                                    <span className="mt-1 block text-xs text-ink-faint">
                                        {formatRelative(n.created_at)}
                                    </span>
                                </span>

                                {!n.is_read && (
                                    <span className="mt-2 size-1.5 shrink-0 rounded-full bg-brand" />
                                )}
                            </button>
                        );
                    })}
                </div>
            )}
        </div>
    );
}
