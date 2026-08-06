// 03 케이스 목록
import { useEffect, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { Inbox, Search } from 'lucide-react';

import { getBatches, getMe, getSharesToMe, getStaff } from '@/api';
import { qk } from '@/api/keys';
import type { Batch, BatchStatus, Staff } from '@/api/types';
import { FIELD_INPUT } from '@/components/form';
import { ListFrame } from '@/components/ListFrame';
import { Empty, Failed, Pending } from '@/components/QueryState';
import { BatchStatusBadge } from '@/components/StatusBadge';
import { formatShort } from '@/lib/format';
import { BATCH_STATUS_LABEL } from '@/lib/jobStatus';
import { patientBrief } from '@/lib/patient';
import { ROLE_LABEL, staffBrief } from '@/lib/staff';
import { cn } from '@/lib/utils';

// 환자 · 슬라이드 · 확인 필요 · 상태 · 등록
const GRID =
    'grid min-w-[44rem] grid-cols-[minmax(9rem,20rem)_5.5rem_5.5rem_6rem_minmax(0,1fr)] items-center gap-x-5';

const STATUS_FILTERS : { value : BatchStatus | 'all'; label : string }[] = [
    { value: 'all', label: '전체' },
    { value: 'pending', label: BATCH_STATUS_LABEL.pending },
    { value: 'processing', label: BATCH_STATUS_LABEL.processing },
    { value: 'done', label: BATCH_STATUS_LABEL.done },
    { value: 'failed', label: BATCH_STATUS_LABEL.failed },
];

export default function CaseListPage() {
    const [searchParams, setSearchParams] = useSearchParams();

    const status = (searchParams.get('status') ?? 'all') as BatchStatus | 'all';
    const sharedOnly = searchParams.get('from') === 'shared';

    // 검색어는 URL에 넣지 않는다. 왕복하면 한글 조합이 깨져 글자가 중복된다
    const [draft, setDraft] = useState('');
    const [q, setQ] = useState('');

    // 타이핑마다 요청하지 않는다
    useEffect(() => {
        const id = setTimeout(() => setQ(draft.trim()), 300);
        return () => clearTimeout(id);
    }, [draft]);

    // 필터·검색은 서버가 한다. 페이지를 끊는 순간 클라이언트 필터는 이 페이지만 보게 된다
    const batches = useQuery({
        queryKey: qk.batchList({ status, q, shared: sharedOnly }),
        queryFn: () => getBatches({
            status: status === 'all' ? undefined : status,
            q: q || undefined,
            shared: sharedOnly || undefined,
        }),
    });

    // 소유자만 공유할 수 있다 >> created_by가 곧 공유한 사람
    const { data: me } = useQuery({ queryKey: qk.me, queryFn: getMe });
    const { data: staff } = useQuery({ queryKey: qk.staff, queryFn: getStaff });

    function setParam(key : string, value : string) {
        const next = new URLSearchParams(searchParams);
        if (value && value !== 'all') next.set(key, value);
        else next.delete(key);
        setSearchParams(next, { replace: true });
    }

    const staffById = new Map<string, Staff>((staff ?? []).map((s) => [s.id, s]));
    const sharedWithMe = (batch : Batch) : boolean => !!me && batch.created_by !== me.id;

    // 의견·받은 시각은 배치가 아니라 공유에 붙어 있다
    const { data: shares } = useQuery({ queryKey: qk.sharesIn, queryFn: getSharesToMe });
    const shareByBatch = new Map((shares ?? []).map((s) => [s.batch, s]));

    // sharedLabel >> 보낸 사람 · 진료과. 받은 시각은 툴팁으로
    function sharedLabel(batch : Batch) : { text : string; title : string } {
        const from = staffById.get(batch.created_by);
        const share = shareByBatch.get(batch.id);

        const who = from ? staffBrief(from) : batch.created_by.slice(0, 8);
        const detail = [
            from && ROLE_LABEL[from.role],
            share && `${formatShort(share.created_at)} 받음`,
        ].filter(Boolean);

        return { text: who, title: [who, ...detail].join(' · ') };
    }

    const opinionOf = (batch : Batch) : string =>
        sharedWithMe(batch) ? (shareByBatch.get(batch.id)?.opinion ?? '') : '';

    // 서버가 정렬·필터를 끝낸 목록. 슬라이드 수와 확인 필요 수도 응답에 들어 있다
    const matched = (batches.data?.results ?? []).map((batch) => ({
        batch,
        slides: batch.image_count,
        review: batch.needs_review_count,
    }));

    const total = batches.data?.count ?? 0;
    // 서버가 끊어 준 페이지보다 전체가 많으면 알린다
    const hidden = Math.max(0, total - (batches.data?.results.length ?? 0));

    return (
        <div>
            <div className="mb-6 flex flex-wrap items-center gap-3">
                <div className="relative">
                    <Search
                        size={15}
                        className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-ink-faint"
                    />
                    <input
                        value={draft}
                        onChange={(e) => setDraft(e.target.value)}
                        placeholder="차트번호 또는 환자명"
                        aria-label="환자 검색"
                        className={`${FIELD_INPUT} w-72 pl-9`}
                    />
                </div>

                <div className="flex items-center gap-0.5 rounded-md border border-border p-0.5">
                    {/* 상태별 건수는 서버가 걸러 주므로 이 페이지만으로는 셀 수 없다 */}
                    {STATUS_FILTERS.map((f) => (
                        <button
                            key={f.value}
                            type="button"
                            onClick={() => setParam('status', f.value)}
                            aria-pressed={status === f.value}
                            className={cn(
                                'flex h-8 items-center rounded px-2.5 text-sm transition-colors',
                                status === f.value
                                    ? 'bg-surface-raised font-medium text-ink shadow-sm'
                                    : 'text-ink-muted hover:bg-ink/[0.04] hover:text-ink',
                            )}
                        >
                            {f.label}
                        </button>
                    ))}
                </div>

                <button
                    type="button"
                    onClick={() => setParam('from', sharedOnly ? '' : 'shared')}
                    aria-pressed={sharedOnly}
                    className={cn(
                        'flex h-9 items-center gap-1.5 rounded-md px-2.5 text-sm transition-colors',
                        sharedOnly
                            ? 'bg-ink/[0.06] font-medium text-ink'
                            : 'text-ink-muted hover:bg-ink/[0.04] hover:text-ink',
                    )}
                >
                    <Inbox size={14} />
                    공유받음만
                </button>

                <span className="ml-auto text-[15px] text-ink-muted">
                    {batches.isSuccess ? `${total}건` : ''}
                </span>
            </div>

            {/* 서버가 한 번에 50건까지만 준다. 나머지가 있다는 걸 숨기지 않는다 */}
            {hidden > 0 && (
                <p className="mb-3 text-sm text-ink-muted">
                    {total}건 중 {matched.length}건을 보고 있습니다. 검색이나 상태로 좁혀 주세요
                </p>
            )}

            <ListFrame
                grid={GRID}
                header={
                    <>
                        <span>환자</span>
                        <span className="text-right">슬라이드</span>
                        <span className="text-right">확인 필요</span>
                        <span>상태</span>
                        <span className="text-right">등록</span>
                    </>
                }
            >
                {batches.isPending ? (
                    <Pending />
                ) : batches.isError ? (
                    <Failed error={batches.error} onRetry={() => void batches.refetch()} />
                ) : matched.length === 0 ? (
                    <Empty label="조건에 맞는 케이스가 없습니다" />
                ) : (
                    <div className="divide-y divide-border">
                        {matched.map((row) => (
                            <Link
                                key={row.batch.id}
                                to={`/batches/${row.batch.id}`}
                                className={cn(
                                    GRID,
                                    'py-4 transition-colors hover:bg-brand-soft/50',
                                )}
                            >
                                <span className="flex min-w-0 items-center gap-2">
                                    <span
                                        className="truncate text-[15px]"
                                        title={
                                            row.batch.patient_summary
                                                ? patientBrief(row.batch.patient_summary)
                                                : undefined
                                        }
                                    >
                                        {row.batch.patient_summary ? (
                                            patientBrief(row.batch.patient_summary)
                                        ) : (
                                            <>
                                                환자 미연결{' '}
                                                <span className="font-mono text-sm text-ink-faint">
                                                    {row.batch.id.slice(0, 8)}
                                                </span>
                                            </>
                                        )}
                                    </span>

                                    {sharedWithMe(row.batch) && (
                                        <span
                                            title={sharedLabel(row.batch).title}
                                            className="shrink-0 rounded border border-border px-1.5 py-0.5 text-[11px] text-ink-faint"
                                        >
                                            공유받음 · {sharedLabel(row.batch).text}
                                        </span>
                                    )}
                                </span>

                                <span className="text-right font-mono text-[15px] tabular-nums">
                                    {row.slides ?? '-'}
                                </span>

                                {/* 0은 흐리게, 1 이상은 눈에 걸리게. 모르면 '-' */}
                                <span
                                    className={cn(
                                        'text-right font-mono text-[15px] tabular-nums',
                                        row.review
                                            ? 'font-semibold text-decision-abstain'
                                            : 'text-ink-faint',
                                    )}
                                >
                                    {row.review ?? '-'}
                                </span>

                                <span>
                                    <BatchStatusBadge status={row.batch.status} />
                                </span>

                                <span className="text-right text-sm text-ink-muted">
                                    {formatShort(row.batch.created_at)}
                                </span>

                                {opinionOf(row.batch) && (
                                    <span
                                        title={opinionOf(row.batch)}
                                        className="col-span-full mt-1.5 truncate text-[13px] text-ink-muted"
                                    >
                                        {opinionOf(row.batch)}
                                    </span>
                                )}
                            </Link>
                        ))}
                    </div>
                )}
            </ListFrame>
        </div>
    );
}
