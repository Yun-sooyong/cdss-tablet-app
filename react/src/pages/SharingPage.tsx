// 12 공유 보내기
import { useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import {
    createShare,
    getBatches,
    getMe,
    getSharesSentByMe,
    getStaff,
    revokeShare,
} from '@/api';
import { qk } from '@/api/keys';
import type { Batch, SharePermission, Staff } from '@/api/types';
import { BUTTON_PRIMARY, FIELD_INPUT } from '@/components/form';
import { Failed, Pending } from '@/components/QueryState';
import { StateBadge } from '@/components/StateBadge';
import { formatShort } from '@/lib/format';
import { patientBrief } from '@/lib/patient';
import { PERMISSION_LABEL, SHARE_STATE_LABEL, shareState } from '@/lib/share';
import { staffBrief } from '@/lib/staff';
import { cn } from '@/lib/utils';

const GRID =
    'grid grid-cols-[minmax(9rem,1.6fr)_minmax(7rem,1fr)_4rem_5rem_6rem_3.5rem] items-center gap-x-5';

const PERMISSION_OPTIONS : SharePermission[] = ['read', 'comment'];

// days 0 >> 만료 없음
const EXPIRY_OPTIONS = [
    { days: 0, label: '만료 없음' },
    { days: 7, label: '7일' },
    { days: 30, label: '30일' },
];

const expiresAt = (days : number) : string | null => {
    if (!days) return null;

    const at = new Date();
    at.setDate(at.getDate() + days);
    return at.toISOString();
};

const labelOf = (batch? : Batch, id? : string) : string => {
    const who = batch?.patient_summary ? patientBrief(batch.patient_summary) : '환자 미연결';
    return `${who} · ${(batch?.id ?? id ?? '').slice(0, 8)}`;
};

export default function SharingPage() {
    const [searchParams, setSearchParams] = useSearchParams();
    const queryClient = useQueryClient();

    const { data: me } = useQuery({ queryKey: qk.me, queryFn: getMe });
    const { data: batches } = useQuery({ queryKey: qk.batches, queryFn: getBatches });
    const { data: staff } = useQuery({ queryKey: qk.staff, queryFn: getStaff });

    const sent = useQuery({ queryKey: qk.sharesOut, queryFn: getSharesSentByMe });

    // 공유 대상 >> 재직자(getStaff) 중 본인 제외
    const targets = (staff ?? []).filter((s) => s.id !== me?.id);
    const staffById = new Map<string, Staff>((staff ?? []).map((s) => [s.id, s]));
    const batchById = new Map<string, Batch>((batches ?? []).map((b) => [b.id, b]));

    const batchId = searchParams.get('batch') ?? '';
    const [targetId, setTargetId] = useState('');
    const [permission, setPermission] = useState<SharePermission>('read');
    const [days, setDays] = useState(0);
    const [error, setError] = useState('');

    function setBatch(next : string) {
        const params = new URLSearchParams(searchParams);
        if (next) params.set('batch', next);
        else params.delete('batch');

        setSearchParams(params, { replace: true });
        setError('');
    }

    const send = useMutation({
        mutationFn: () =>
            createShare(batchId, {
                shared_to: targetId,
                permission,
                expires_at: expiresAt(days),
            }),
        onSuccess: (share) => {
            void queryClient.invalidateQueries({ queryKey: qk.sharesOut });
            setTargetId('');
            setError('');
            toast('공유했습니다', {
                description: `${labelOf(batchById.get(share.batch), share.batch)} → ${
                    staffById.get(share.shared_to)?.username ?? share.shared_to
                }`,
            });
        },
        onError: (err : Error) => setError(err.message || '공유하지 못했습니다.'),
    });

    const revoke = useMutation({
        mutationFn: (shareId : string) => revokeShare(shareId),
        onSuccess: () => {
            void queryClient.invalidateQueries({ queryKey: qk.sharesOut });
            toast('공유를 회수했습니다');
        },
        onError: (err : Error) => toast('회수하지 못했습니다', { description: err.message }),
    });

    function confirmRevoke(shareId : string, username : string) {
        if (!window.confirm(`${username}에게 보낸 공유를 회수합니다.`)) return;
        revoke.mutate(shareId);
    }

    return (
        <div>
            <section className="mb-10">
                <h2 className="mb-3 text-base font-medium">새 공유</h2>

                <div className="rounded-lg border border-border p-4">
                    <div className="grid gap-3 md:grid-cols-2">
                        <label className="block">
                            <span className="mb-1.5 block text-xs text-ink-muted">케이스</span>
                            <select
                                value={batchId}
                                onChange={(e) => setBatch(e.target.value)}
                                className={FIELD_INPUT}
                            >
                                <option value="">선택하세요</option>
                                {(batches ?? []).map((batch) => (
                                    <option key={batch.id} value={batch.id}>
                                        {labelOf(batch)}
                                    </option>
                                ))}
                            </select>
                        </label>

                        <label className="block">
                            <span className="mb-1.5 block text-xs text-ink-muted">받는 사람</span>
                            <select
                                value={targetId}
                                onChange={(e) => {
                                    setTargetId(e.target.value);
                                    setError('');
                                }}
                                className={FIELD_INPUT}
                            >
                                <option value="">선택하세요</option>
                                {targets.map((s) => (
                                    <option key={s.id} value={s.id}>
                                        {staffBrief(s)}
                                    </option>
                                ))}
                            </select>
                        </label>

                        <label className="block">
                            <span className="mb-1.5 block text-xs text-ink-muted">권한</span>
                            <select
                                value={permission}
                                onChange={(e) =>
                                    setPermission(e.target.value as SharePermission)
                                }
                                className={FIELD_INPUT}
                            >
                                {PERMISSION_OPTIONS.map((p) => (
                                    <option key={p} value={p}>
                                        {PERMISSION_LABEL[p]}
                                    </option>
                                ))}
                            </select>
                        </label>

                        <label className="block">
                            <span className="mb-1.5 block text-xs text-ink-muted">유효기간</span>
                            <select
                                value={days}
                                onChange={(e) => setDays(Number(e.target.value))}
                                className={FIELD_INPUT}
                            >
                                {EXPIRY_OPTIONS.map((o) => (
                                    <option key={o.days} value={o.days}>
                                        {o.label}
                                    </option>
                                ))}
                            </select>
                        </label>
                    </div>

                    {error && (
                        <p role="alert" className="mt-3 text-sm text-danger">
                            {error}
                        </p>
                    )}

                    <button
                        type="button"
                        onClick={() => send.mutate()}
                        disabled={!batchId || !targetId || send.isPending}
                        className={`mt-4 ${BUTTON_PRIMARY}`}
                    >
                        공유
                    </button>
                </div>
            </section>

            <section>
                <div className="mb-3 flex items-baseline justify-between">
                    <h2 className="text-base font-medium">보낸 내역</h2>
                    <span className="text-sm text-ink-muted">
                        {sent.data ? `${sent.data.length}건` : ''}
                    </span>
                </div>

                <div
                    className={cn(
                        GRID,
                        'mb-1.5 border-b border-border pb-1.5 text-xs text-ink-muted',
                    )}
                >
                    <span>케이스</span>
                    <span>받는 사람</span>
                    <span>권한</span>
                    <span>상태</span>
                    <span className="text-right">보낸 시각</span>
                    <span />
                </div>

                {sent.isPending ? (
                    <Pending />
                ) : sent.isError ? (
                    <Failed error={sent.error} onRetry={() => void sent.refetch()} />
                ) : sent.data.length === 0 ? (
                    <div className="py-16 text-center text-sm text-ink-faint">
                        보낸 공유가 없습니다
                    </div>
                ) : (
                    <div className="divide-y divide-border">
                        {sent.data.map((share) => {
                            const state = shareState(share);
                            const target = staffById.get(share.shared_to);
                            const batch = batchById.get(share.batch);

                            return (
                                <div
                                    key={share.id}
                                    className={cn(GRID, 'py-4', state !== 'live' && 'opacity-60')}
                                >
                                    <Link
                                        to={`/batches/${share.batch}`}
                                        className="min-w-0 transition-colors hover:text-brand"
                                    >
                                        <span className="block truncate text-[15px]">
                                            {batch?.patient_summary
                                                ? patientBrief(batch.patient_summary)
                                                : '환자 미연결'}
                                        </span>
                                        <span className="block truncate font-mono text-[13px] text-ink-faint">
                                            {share.batch.slice(0, 8)}
                                        </span>
                                    </Link>

                                    <span className="truncate text-sm text-ink-muted">
                                        {target ? staffBrief(target) : '알 수 없음'}
                                    </span>

                                    <span className="text-sm text-ink-muted">
                                        {PERMISSION_LABEL[share.permission]}
                                    </span>

                                    <span>
                                        <StateBadge
                                            label={SHARE_STATE_LABEL[state]}
                                            live={state === 'live'}
                                        />
                                    </span>

                                    <span className="text-right text-sm text-ink-muted">
                                        {formatShort(share.created_at)}
                                    </span>

                                    {state === 'live' ? (
                                        <button
                                            type="button"
                                            onClick={() =>
                                                confirmRevoke(
                                                    share.id,
                                                    target ? target.username : '상대',
                                                )
                                            }
                                            disabled={revoke.isPending}
                                            className="justify-self-end text-sm text-ink-faint transition-colors hover:text-danger disabled:opacity-40"
                                        >
                                            회수
                                        </button>
                                    ) : (
                                        <span />
                                    )}
                                </div>
                            );
                        })}
                    </div>
                )}
            </section>
        </div>
    );
}
