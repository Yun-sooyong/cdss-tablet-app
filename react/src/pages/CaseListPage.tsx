import { Link, useSearchParams } from 'react-router-dom';
import { Search } from 'lucide-react';

import { getBatches, getJobsByBatch } from '@/api';
import type { Batch, BatchStatus } from '@/api/types';
import { BatchStatusBadge } from '@/components/StatusBadge';
import { needsReview } from '@/lib/decision';
import { BATCH_STATUS_LABEL } from '@/lib/jobStatus';
import { patientBrief } from '@/lib/patient';
import { cn } from '@/lib/utils';

const GRID =
    'grid grid-cols-[minmax(9rem,16rem)_7rem_5.5rem_5.5rem_6rem_minmax(0,1fr)] items-center gap-x-5';

const STATUS_FILTERS : { value : BatchStatus | 'all'; label : string }[] = [
    { value: 'all', label: '전체' },
    { value: 'pending', label: BATCH_STATUS_LABEL.pending },
    { value: 'processing', label: BATCH_STATUS_LABEL.processing },
    { value: 'done', label: BATCH_STATUS_LABEL.done },
    { value: 'failed', label: BATCH_STATUS_LABEL.failed },
];

interface Row {
    batch : Batch;
    slides : number;
    review : number;
}

// 운영 관점이라 시간 축이다. 값 축은 07 09가 맡는다.
function buildRows() : Row[] {
    return getBatches()
        .map((batch) => {
            const jobs = getJobsByBatch(batch.id);
            return {
                batch,
                slides: jobs.length,
                review: jobs.filter((j) => needsReview(j.result)).length,
            };
        })
        .sort(
            (a, b) =>
                new Date(b.batch.created_at).getTime() -
                new Date(a.batch.created_at).getTime(),
        );
}

export default function CaseListPage() {
    const [searchParams, setSearchParams] = useSearchParams();

    const query = searchParams.get('q') ?? '';
    const status = (searchParams.get('status') ?? 'all') as BatchStatus | 'all';

    function setParam(key : string, value : string) {
        const next = new URLSearchParams(searchParams);
        if (value && value !== 'all') next.set(key, value);
        else next.delete(key);
        setSearchParams(next, { replace: true });
    }

    const rows = buildRows().filter((row) => {
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
            <div className="mb-6 flex items-baseline justify-between">
                <h1 className="text-xl font-semibold">케이스 목록</h1>
                <span className="text-[15px] text-ink-muted">{rows.length}건</span>
            </div>

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
                        className="h-10 w-72 rounded-md border border-border bg-surface pl-9 pr-3 text-[15px] text-ink placeholder:text-ink-faint focus:border-brand focus:outline-none"
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
            </div>

            <div
                className={cn(
                    GRID,
                    'mb-1.5 border-b border-border pb-1.5 text-xs text-ink-muted',
                )}
            >
                <span>환자</span>
                <span>배치</span>
                <span className="text-right">슬라이드</span>
                <span className="text-right">확인 필요</span>
                <span>상태</span>
                <span className="text-right">등록</span>
            </div>

            {rows.length === 0 ? (
                <div className="py-16 text-center text-sm text-ink-faint">
                    조건에 맞는 케이스가 없습니다.
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
                                {row.batch.patient_summary
                                    ? patientBrief(row.batch.patient_summary)
                                    : '환자 미연결'}
                            </span>

                            <span className="font-mono text-sm text-ink-muted">
                                {row.batch.id.slice(0, 8)}
                            </span>

                            <span className="text-right font-mono text-[15px] tabular-nums">
                                {row.slides}
                            </span>

                            <span
                                className={cn(
                                    'text-right font-mono text-[15px] tabular-nums',
                                    row.review > 0
                                        ? 'font-semibold text-decision-abstain'
                                        : 'text-ink-faint',
                                )}
                            >
                                {row.review > 0 ? row.review : '-'}
                            </span>

                            <span>
                                <BatchStatusBadge status={row.batch.status} />
                            </span>

                            <span className="text-right text-sm text-ink-muted">
                                {new Date(row.batch.created_at).toLocaleString('ko-KR', {
                                    month: '2-digit',
                                    day: '2-digit',
                                    hour: '2-digit',
                                    minute: '2-digit',
                                })}
                            </span>
                        </Link>
                    ))}
                </div>
            )}
        </div>
    );
}
