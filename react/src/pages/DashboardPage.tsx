// 대시보드
import { Link } from 'react-router-dom';
import { useQueries, useQuery } from '@tanstack/react-query';
import { ArrowRight } from 'lucide-react';

import { getBatches, getJobsByBatch, getLatestJobs } from '@/api';
import { qk } from '@/api/keys';
import { AXIS_GRID, IntervalAxis } from '@/components/IntervalAxis';
import { IntervalBar } from '@/components/IntervalBar';
import { Failed, Pending } from '@/components/QueryState';
import { BatchStatusBadge, DecisionBadge } from '@/components/StatusBadge';
import { CUTOFF, needsReview, toIntervalView } from '@/lib/decision';
import { formatShort } from '@/lib/format';
import { patientLabel } from '@/lib/patient';
import { cn } from '@/lib/utils';

const PREVIEW_COUNT = 5;

export default function DashboardPage() {
    const batches = useQuery({ queryKey: qk.batchList(), queryFn: () => getBatches() });
    const jobs = useQuery({ queryKey: qk.latestJobs, queryFn: getLatestJobs });

    const all = batches.data?.results ?? [];

    const recent = all
        .slice()
        .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
        .slice(0, PREVIEW_COUNT);

    // 슬라이드 수 >> 배치 목록 응답에 없어 미리보기 행만 따로 조회
    const slideQueries = useQueries({
        queries: recent.map((batch) => ({
            queryKey: qk.jobsByBatch(batch.id),
            queryFn: () => getJobsByBatch(batch.id),
        })),
    });

    if (batches.isPending) return <Pending />;
    if (batches.isError) {
        return <Failed error={batches.error} onRetry={() => void batches.refetch()} />;
    }

    const review = (jobs.data ?? []).filter((j) => needsReview(j.result));

    // 배치 기준 >> 서버가 한 페이지만 주므로 이 건수는 최근 것 기준이다
    const processing = all.filter((b) => b.status === 'processing').length;
    const done = all.filter((b) => b.status === 'done').length;
    const failed = all.filter((b) => b.status === 'failed').length;

    return (
        <div>
            <div className="mb-8 flex flex-wrap items-center gap-x-1 text-sm">
                <StatLink to="/cases?status=processing" label="진행 중" value={processing} />
                <Dot />
                <StatLink to="/cases?status=done" label="완료" value={done} />
                <Dot />
                <StatLink
                    to="/cases?status=failed"
                    label="실패"
                    value={failed}
                    accent={failed > 0}
                />
            </div>

            {review.length > 0 && (
                <section className="mb-10">
                    <SectionHeader title="확인 필요" count={review.length} accent to="/review" />

                    <IntervalAxis
                        cutoff={CUTOFF}
                        leading={<span>환자 · 슬라이드</span>}
                        trailing={
                            <>
                                <span className="text-right">sTIL %</span>
                                <span className="text-right">불확실성 σ</span>
                                <span className="text-right">판정</span>
                            </>
                        }
                    >
                        <div className="divide-y divide-border">
                            {review.slice(0, PREVIEW_COUNT).map((job) => {
                                const result = job.result!;
                                return (
                                    <Link
                                        key={job.id}
                                        to={`/results/${job.id}`}
                                        className={cn(
                                            AXIS_GRID,
                                            'py-4 transition-colors hover:bg-brand-soft/50',
                                        )}
                                    >
                                        <span className="min-w-0">
                                            <span
                                                className="block truncate text-[15px]"
                                                title={patientLabel(job.patient_summary)}
                                            >
                                                {patientLabel(job.patient_summary)}
                                            </span>
                                            <span className="block truncate text-[13px] text-ink-faint">
                                                {job.image_summary?.original_filename ?? job.id.slice(0, 8)}
                                            </span>
                                        </span>

                                        <IntervalBar
                                            view={toIntervalView(result)}
                                            decision={result.decision}
                                        />

                                        <span className="text-right font-mono text-base tabular-nums">
                                            {result.stil_value.toFixed(1)}
                                        </span>
                                        <span className="text-right font-mono text-sm tabular-nums text-ink-muted">
                                            {result.sigma.toFixed(1)}
                                        </span>
                                        <span className="flex justify-end">
                                            <DecisionBadge decision={result.decision} />
                                        </span>
                                    </Link>
                                );
                            })}
                        </div>
                    </IntervalAxis>
                </section>
            )}

            <section>
                <SectionHeader title="최근 판독" to="/cases" />

                {recent.length === 0 ? (
                    <div className="py-10 text-center text-sm text-ink-faint">
                        등록된 케이스가 없습니다
                    </div>
                ) : (
                    <div className="divide-y divide-border">
                        {recent.map((batch, at) => (
                            <Link
                                key={batch.id}
                                to={`/batches/${batch.id}`}
                                className="flex items-center gap-4 py-4 transition-colors hover:bg-brand-soft/50"
                            >
                                <span
                                    className="min-w-0 flex-1 truncate text-[15px]"
                                    title={patientLabel(batch.patient_summary)}
                                >
                                    {patientLabel(batch.patient_summary)}
                                </span>
                                <span className="font-mono text-sm tabular-nums text-ink-muted">
                                    슬라이드 {slideQueries[at]?.data?.length ?? '-'}
                                </span>
                                <BatchStatusBadge status={batch.status} />
                                <span className="w-24 text-right text-sm text-ink-muted">
                                    {formatShort(batch.created_at)}
                                </span>
                            </Link>
                        ))}
                    </div>
                )}
            </section>
        </div>
    );
}

function StatLink({
    to,
    label,
    value,
    accent,
} : {
    to : string;
    label : string;
    value : number;
    accent? : boolean;
}) {
    return (
        <Link
            to={to}
            className="rounded-md px-2 py-1 text-ink-muted transition-colors hover:bg-brand-soft/60 hover:text-ink"
        >
            {label}{' '}
            <span
                className={cn(
                    'font-mono tabular-nums text-ink',
                    accent && 'font-semibold text-danger',
                )}
            >
                {value}
            </span>
            건
        </Link>
    );
}

function Dot() {
    return <span className="text-ink-faint">·</span>;
}

function SectionHeader({
    title,
    count,
    accent,
    to,
} : {
    title : string;
    count? : number;
    accent? : boolean;
    to : string;
}) {
    return (
        <div className="mb-3 flex items-baseline justify-between">
            <h2 className="flex items-baseline gap-2 text-base font-medium">
                {title}
                {count !== undefined && (
                    <span
                        className={cn(
                            'font-mono text-sm tabular-nums text-ink-muted',
                            accent && 'font-semibold text-decision-abstain',
                        )}
                    >
                        {count}건
                    </span>
                )}
            </h2>
            <Link
                to={to}
                className="inline-flex items-center gap-1 text-sm text-ink-muted transition-colors hover:text-ink"
            >
                전체 보기
                <ArrowRight size={14} />
            </Link>
        </div>
    );
}
