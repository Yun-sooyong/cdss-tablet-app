// 12 공유 보내기
import { useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { UserX } from 'lucide-react';
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
import type { Batch, Staff } from '@/api/types';
import { BUTTON_PRIMARY, FIELD_INPUT } from '@/components/form';
import { ListFrame } from '@/components/ListFrame';
import { Empty, Failed, Pending } from '@/components/QueryState';
import { StateBadge } from '@/components/StateBadge';
import { formatShort } from '@/lib/format';
import { patientLabel } from '@/lib/patient';
import { SHARE_STATE_LABEL, shareState } from '@/lib/share';
import { staffBrief } from '@/lib/staff';
import { cn } from '@/lib/utils';

const GRID =
    'grid min-w-[52rem] grid-cols-[minmax(9rem,1.3fr)_minmax(7rem,0.9fr)_minmax(10rem,1.8fr)_5rem_6rem_3.5rem] items-center gap-x-5';

// 서버가 opinion을 200자로 자른다
const OPINION_MAX = 200;

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
    const who = patientLabel(batch?.patient_summary ?? null);
    return `${who} · ${(batch?.id ?? id ?? '').slice(0, 8)}`;
};

export default function SharingPage() {
    const [searchParams, setSearchParams] = useSearchParams();
    const queryClient = useQueryClient();

    const { data: me } = useQuery({ queryKey: qk.me, queryFn: getMe });
    const { data: batchPage } = useQuery({ queryKey: qk.batchList(), queryFn: () => getBatches() });
    const batches = batchPage?.results;
    const { data: staff } = useQuery({ queryKey: qk.staff, queryFn: getStaff });

    const sent = useQuery({ queryKey: qk.sharesOut, queryFn: getSharesSentByMe });

    // 공유 대상 >> 재직자(getStaff) 중 본인 제외
    const targets = (staff ?? []).filter((s) => s.id !== me?.id);

    // 서버가 소유자만 공유를 허용한다. 공유받은 배치를 고르면 404가 난다
    const mine = (batches ?? []).filter((b) => b.created_by === me?.id);

    // 담당의는 LOW/HIGH만 받는다. 기권은 병리의가 확정한 뒤에야 넘어간다
    // needs_review_count >> 아직 확정되지 않은 ABSTAIN 수 (서버 집계)
    const shareable = mine.filter(
        (b) => b.status === 'done' && b.needs_review_count === 0,
    );
    const held = mine.length - shareable.length;
    const staffById = new Map<string, Staff>((staff ?? []).map((s) => [s.id, s]));
    const batchById = new Map<string, Batch>((batches ?? []).map((b) => [b.id, b]));

    const batchId = searchParams.get('batch') ?? '';
    const ownsPicked = shareable.some((b) => b.id === batchId);

    const [targetId, setTargetId] = useState('');
    const [opinion, setOpinion] = useState('');
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
                opinion: opinion.trim(),
                expires_at: expiresAt(days),
            }),
        onSuccess: (share) => {
            void queryClient.invalidateQueries({ queryKey: qk.sharesOut });
            setTargetId('');
            setOpinion('');
            setError('');
            toast.success('공유했습니다', {
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
            toast.success('공유를 회수했습니다');
        },
        onError: (err : Error) => toast.error('회수하지 못했습니다', { description: err.message }),
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
                                <option value="">
                                    {shareable.length === 0
                                        ? '공유할 케이스가 없습니다'
                                        : '선택하세요'}
                                </option>
                                {shareable.map((batch) => (
                                    <option key={batch.id} value={batch.id}>
                                        {labelOf(batch)}
                                    </option>
                                ))}
                            </select>

                            {mine.length === 0 ? (
                                <span className="mt-1.5 block text-xs text-ink-faint">
                                    내가 등록한 케이스만 공유할 수 있습니다
                                </span>
                            ) : held > 0 && (
                                <span className="mt-1.5 block text-xs text-ink-faint">
                                    판정이 끝나지 않은 {held}건은 공유할 수 없습니다
                                </span>
                            )}
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

                        <label className="block md:col-span-2">
                            <span className="mb-1.5 flex items-baseline justify-between text-xs text-ink-muted">
                                <span>의견 (선택)</span>
                                <span
                                    className={cn(
                                        'font-mono tabular-nums',
                                        opinion.length === OPINION_MAX && 'text-danger',
                                    )}
                                >
                                    {opinion.length}/{OPINION_MAX}
                                </span>
                            </span>
                            <textarea
                                value={opinion}
                                onChange={(e) => setOpinion(e.target.value)}
                                maxLength={OPINION_MAX}
                                rows={3}
                                placeholder="받는 사람이 함께 볼 메모를 남길 수 있습니다"
                                className={`${FIELD_INPUT} h-auto resize-y py-2 leading-relaxed`}
                            />
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
                        disabled={!ownsPicked || !targetId || send.isPending}
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

                <ListFrame
                    grid={GRID}
                    header={
                        <>
                            <span>케이스</span>
                            <span>받는 사람</span>
                            <span>의견</span>
                            <span>상태</span>
                            <span className="text-right">보낸 시각</span>
                            <span />
                        </>
                    }
                >
                    {sent.isPending ? (
                        <Pending />
                    ) : sent.isError ? (
                        <Failed error={sent.error} onRetry={() => void sent.refetch()} />
                    ) : sent.data.length === 0 ? (
                        <Empty label="보낸 공유가 없습니다" />
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
                                            <span
                                                className="block truncate text-base"
                                                title={patientLabel(batch?.patient_summary ?? null)}
                                            >
                                                {patientLabel(batch?.patient_summary ?? null)}
                                            </span>
                                            <span className="block truncate font-mono text-sm text-ink-faint">
                                                {share.batch.slice(0, 8)}
                                            </span>
                                        </Link>

                                        <span className="truncate text-sm text-ink-muted">
                                            {target ? staffBrief(target) : '알 수 없음'}
                                        </span>

                                        <span
                                            className={cn(
                                                'truncate text-sm',
                                                share.opinion ? 'text-ink-muted' : 'text-ink-faint',
                                            )}
                                            title={share.opinion || undefined}
                                        >
                                            {share.opinion || '없음'}
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
                                                aria-label={`${target ? target.username : '상대'}에게 보낸 공유 회수`}
                                                className="flex items-center justify-self-end gap-1 text-sm text-ink-faint transition-colors hover:text-danger disabled:opacity-40"
                                            >
                                                <UserX size={14} />
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
                </ListFrame>
            </section>
        </div>
    );
}
