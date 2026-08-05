// 03 케이스 목록
import { useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { useQueries, useQuery } from '@tanstack/react-query';
import { Inbox, Search } from 'lucide-react';

import { getBatches, getJobsByBatch, getMe, getSharesToMe, getStaff } from '@/api';
import { qk } from '@/api/keys';
import type { Batch, BatchStatus, Staff } from '@/api/types';
import { FIELD_INPUT } from '@/components/form';
import { ListFrame } from '@/components/ListFrame';
import { Empty, Failed, Pending } from '@/components/QueryState';
import { BatchStatusBadge } from '@/components/StatusBadge';
import { needsReview } from '@/lib/decision';
import { formatShort } from '@/lib/format';
import { BATCH_STATUS_LABEL } from '@/lib/jobStatus';
import { patientBrief } from '@/lib/patient';
import { PERMISSION_LABEL } from '@/lib/share';
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

    const batches = useQuery({ queryKey: qk.batches, queryFn: getBatches });

    // 소유자만 공유할 수 있다 >> created_by가 곧 공유한 사람
    const { data: me } = useQuery({ queryKey: qk.me, queryFn: getMe });
    const { data: staff } = useQuery({ queryKey: qk.staff, queryFn: getStaff });

    // 슬라이드 수 · 확인 필요 >> 배치 목록 응답에 없어 배치마다 따로 조회
    const jobQueries = useQueries({
        queries: (batches.data ?? []).map((batch) => ({
            queryKey: qk.jobsByBatch(batch.id),
            queryFn: () => getJobsByBatch(batch.id),
        })),
    });

    function setParam(key : string, value : string) {
        const next = new URLSearchParams(searchParams);
        if (value && value !== 'all') next.set(key, value);
        else next.delete(key);
        setSearchParams(next, { replace: true });
    }

    // 검색어는 URL에 넣지 않는다. 왕복하면 한글 조합이 깨져 글자가 중복된다
    const [draft, setDraft] = useState('');

    const staffById = new Map<string, Staff>((staff ?? []).map((s) => [s.id, s]));
    const sharedWithMe = (batch : Batch) : boolean => !!me && batch.created_by !== me.id;

    // 권한·받은 시각은 배치가 아니라 공유에 붙어 있다
    const { data: shares } = useQuery({ queryKey: qk.sharesIn, queryFn: getSharesToMe });
    const shareByBatch = new Map((shares ?? []).map((s) => [s.batch, s]));

    // sharedLabel >> 보낸 사람 · 진료과. 권한과 시각은 툴팁으로
    function sharedLabel(batch : Batch) : { text : string; title : string } {
        const from = staffById.get(batch.created_by);
        const share = shareByBatch.get(batch.id);

        const who = from ? staffBrief(from) : batch.created_by.slice(0, 8);
        const detail = [
            from && ROLE_LABEL[from.role],
            share && `${PERMISSION_LABEL[share.permission]} 권한`,
            share && `${formatShort(share.created_at)} 받음`,
        ].filter(Boolean);

        return { text: who, title: [who, ...detail].join(' · ') };
    }

    const scoped = (batches.data ?? [])
        .map((batch, at) => {
            const jobs = jobQueries[at]?.data;

            return {
                batch,
                slides: jobs?.length,
                review: jobs?.filter((j) => needsReview(j.result)).length,
            };
        })
        .sort(
            (a, b) =>
                new Date(b.batch.created_at).getTime() -
                new Date(a.batch.created_at).getTime(),
        )
        .filter((row) => !sharedOnly || sharedWithMe(row.batch));

    const countOf = (value : BatchStatus | 'all') : number =>
        value === 'all'
            ? scoped.length
            : scoped.filter((row) => row.batch.status === value).length;

    const rows = scoped.filter((row) => status === 'all' || row.batch.status === status);

    const q = draft.trim().toLowerCase();

    const matched = q
        ? rows.filter((row) => {
              const p = row.batch.patient_summary;
              if (!p) return row.batch.id.toLowerCase().includes(q);

              return (
                  p.chart_number.toLowerCase().includes(q) ||
                  p.name.toLowerCase().includes(q)
              );
          })
        : rows;

    // 환자 미연결이라 검색으로 못 걸린 건수
    const unlinkedHidden = q
        ? rows.filter((row) => !row.batch.patient_summary && !matched.includes(row)).length
        : 0;

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
                    {STATUS_FILTERS.map((f) => {
                        const n = countOf(f.value);

                        return (
                            <button
                                key={f.value}
                                type="button"
                                onClick={() => setParam('status', f.value)}
                                aria-pressed={status === f.value}
                                className={cn(
                                    'flex h-8 items-center gap-1.5 rounded px-2.5 text-sm transition-colors',
                                    status === f.value
                                        ? 'bg-surface-raised font-medium text-ink shadow-sm'
                                        : 'text-ink-muted hover:bg-ink/[0.04] hover:text-ink',
                                )}
                            >
                                {f.label}
                                <span
                                    className={cn(
                                        'font-mono text-xs tabular-nums',
                                        n ? 'text-ink-faint' : 'text-ink-faint/50',
                                    )}
                                >
                                    {n}
                                </span>
                            </button>
                        );
                    })}
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
                    {batches.isSuccess ? `${matched.length}건` : ''}
                </span>
            </div>

            {unlinkedHidden > 0 && (
                <p className="mb-3 text-sm text-ink-muted">
                    환자가 연결되지 않아 검색에서 빠진 케이스 {unlinkedHidden}건이 있습니다.{' '}
                    <button
                        type="button"
                        onClick={() => setDraft('')}
                        className="underline underline-offset-2 transition-colors hover:text-ink"
                    >
                        검색 지우기
                    </button>
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
                            </Link>
                        ))}
                    </div>
                )}
            </ListFrame>
        </div>
    );
}
