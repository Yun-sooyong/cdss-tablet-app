// 대시보드
import { Link } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { ArrowRight } from 'lucide-react';

import { getBatches, getLatestJobs } from '@/api';
import { qk } from '@/api/keys';
import { Failed, Pending } from '@/components/QueryState';
import { BatchStatusBadge, DecisionBadge } from '@/components/StatusBadge';
import { needsReview } from '@/lib/decision';
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

    if (batches.isPending) return <Pending />;
    if (batches.isError) {
        return <Failed error={batches.error} onRetry={() => void batches.refetch()} />;
    }

    const review = (jobs.data ?? []).filter((j) => needsReview(j));

    const total = batches.data?.count ?? 0;

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

            {/* 확인 필요와 최근 판독을 나란히. 좁아지면 위아래로 접힌다 */}
            <div className="grid gap-8 lg:grid-cols-2">
                <section>
                    <SectionHeader title="확인 필요" count={review.length} accent to="/review" />

                    {review.length === 0 ? (
                        <EmptyLine label="확인이 필요한 기권 케이스가 없습니다" />
                    ) : (
                        <div className="divide-y divide-border border-t border-border">
                            {review.slice(0, PREVIEW_COUNT).map((job) => {
                                const result = job.result!;

                                return (
                                    <Link
                                        key={job.id}
                                        to={`/results/${job.id}`}
                                        className="flex items-center gap-3 py-3 transition-colors hover:bg-brand-soft/50"
                                    >
                                        <span className="min-w-0 flex-1">
                                            <span className="block truncate text-base">
                                                {patientLabel(job.patient_summary)}
                                            </span>
                                            <span className="block truncate text-sm text-ink-faint">
                                                {job.image_summary?.original_filename ??
                                                    job.id.slice(0, 8)}
                                            </span>
                                        </span>

                                        <span className="shrink-0 font-mono text-base tabular-nums">
                                            {result.stil_value.toFixed(1)}
                                            <span className="ml-0.5 text-xs text-ink-muted">%</span>
                                        </span>

                                        <DecisionBadge decision={result.decision} />
                                    </Link>
                                );
                            })}
                        </div>
                    )}
                </section>

                <section>
                    <SectionHeader title="최근 판독" count={total} to="/cases" />

                    {recent.length === 0 ? (
                        <EmptyLine label="등록된 케이스가 없습니다" />
                    ) : (
                        <div className="divide-y divide-border border-t border-border">
                            {recent.map((batch) => (
                                <Link
                                    key={batch.id}
                                    to={`/batches/${batch.id}`}
                                    className="flex items-center gap-3 py-3 transition-colors hover:bg-brand-soft/50"
                                >
                                    <span className="min-w-0 flex-1 truncate text-base">
                                        {patientLabel(batch.patient_summary)}
                                    </span>

                                    <span className="shrink-0 font-mono text-sm tabular-nums text-ink-muted">
                                        슬라이드 {batch.image_count}
                                    </span>

                                    <BatchStatusBadge status={batch.status} />

                                    <span className="w-20 shrink-0 text-right text-sm text-ink-muted">
                                        {formatShort(batch.created_at)}
                                    </span>
                                </Link>
                            ))}
                        </div>
                    )}
                </section>
            </div>
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

function EmptyLine({ label } : { label : string }) {
    return (
        <div className="border-t border-border py-10 text-center text-sm text-ink-faint">
            {label}
        </div>
    );
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
