// 03 케이스 목록
import { Link, useSearchParams } from 'react-router-dom';
import { useQueries, useQuery } from '@tanstack/react-query';
import { Search } from 'lucide-react';

import { getBatches, getJobsByBatch } from '@/api';
import { qk } from '@/api/keys';
import type { BatchStatus } from '@/api/types';
import { FIELD_INPUT } from '@/components/form';
import { Failed, Pending } from '@/components/QueryState';
import { BatchStatusBadge } from '@/components/StatusBadge';
import { needsReview } from '@/lib/decision';
import { formatShort } from '@/lib/format';
import { BATCH_STATUS_LABEL } from '@/lib/jobStatus';
import { patientBrief } from '@/lib/patient';
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

    const query = searchParams.get('q') ?? '';
    const status = (searchParams.get('status') ?? 'all') as BatchStatus | 'all';

    const batches = useQuery({ queryKey: qk.batches, queryFn: getBatches });

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

    const rows = (batches.data ?? [])
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
        .filter((row) => {
            if (status !== 'all' && row.batch.status !== status) return false;
            if (!query) return true;

            const p = row.batch.patient_summary;
            if (!p) return false;
            const q = query.toLowerCase();
            return (
                p.chart_number.toLowerCase().includes(q) || p.name.toLowerCase().includes(q)
            );
        });

    return (
        <div>
            <div className="mb-6 flex flex-wrap items-center gap-3">
                <div className="relative">
                    <Search
                        size={15}
                        className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-ink-faint"
                    />
                    <input
                        value={query}
                        onChange={(e) => setParam('q', e.target.value)}
                        placeholder="차트번호 또는 환자명"
                        aria-label="환자 검색"
                        className={`${FIELD_INPUT} w-72 pl-9`}
                    />
                </div>

                <div className="flex items-center gap-1">
                    {STATUS_FILTERS.map((f) => (
                        <button
                            key={f.value}
                            type="button"
                            onClick={() => setParam('status', f.value)}
                            className={cn(
                                'h-10 rounded-md px-3 text-sm transition-colors',
                                status === f.value
                                    ? 'bg-brand-soft font-medium text-ink'
                                    : 'text-ink-muted hover:bg-brand-soft/60 hover:text-ink',
                            )}
                        >
                            {f.label}
                        </button>
                    ))}
                </div>

                <span className="ml-auto text-[15px] text-ink-muted">
                    {batches.isSuccess ? `${rows.length}건` : ''}
                </span>
            </div>

            <div
                className={cn(
                    GRID,
                    'mb-1.5 border-b border-border pb-1.5 text-xs text-ink-muted',
                )}
            >
                <span>환자</span>
                <span className="text-right">슬라이드</span>
                <span className="text-right">확인 필요</span>
                <span>상태</span>
                <span className="text-right">등록</span>
            </div>

            {batches.isPending ? (
                <Pending />
            ) : batches.isError ? (
                <Failed error={batches.error} onRetry={() => void batches.refetch()} />
            ) : rows.length === 0 ? (
                <div className="py-16 text-center text-sm text-ink-faint">
                    조건에 맞는 케이스가 없습니다
                </div>
            ) : (
                <div className="divide-y divide-border">
                    {rows.map((row) => (
                        <Link
                            key={row.batch.id}
                            to={`/batches/${row.batch.id}`}
                            className={cn(
                                GRID,
                                'py-4 transition-colors hover:bg-brand-soft/50',
                            )}
                        >
                            <span className="truncate text-[15px]">
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
        </div>
    );
}
