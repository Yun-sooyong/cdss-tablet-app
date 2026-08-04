import { Link } from 'react-router-dom';
import { ArrowRight } from 'lucide-react';

import { getBatches, getImage, getJobs, getJobsByBatch } from '@/api';
import { AXIS_GRID, IntervalAxis } from '@/components/IntervalAxis';
import { IntervalBar } from '@/components/IntervalBar';
import { BatchStatusBadge, DecisionBadge } from '@/components/StatusBadge';
import { CUTOFF, needsReview, toIntervalView } from '@/lib/decision';
import { patientBrief } from '@/lib/patient';
import { cn } from '@/lib/utils';

const PREVIEW_COUNT = 5;

export default function DashboardPage() {
    const jobs = getJobs();
    const batches = getBatches();

    const review = jobs.filter((j) => needsReview(j.result));

    // 배치 기준
    const processing = batches.filter((b) => b.status === 'processing').length;
    const done = batches.filter((b) => b.status === 'done').length;
    const failed = batches.filter((b) => b.status === 'failed').length;

    const recent = batches
        .slice()
        .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
        .slice(0, PREVIEW_COUNT);

    return (
        <div>
            <h1 className="mb-4 text-xl font-semibold">대시보드</h1>

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
                                            <span className="block truncate text-[15px]">
                                                {job.patient_summary
                                                    ? patientBrief(job.patient_summary)
                                                    : '환자 미연결'}
                                            </span>
                                            <span className="block truncate text-[13px] text-ink-faint">
                                                {getImage(job.image)?.original_filename ??
                                                    job.id.slice(0, 8)}
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
                <SectionHeader title="최근 케이스" to="/cases" />

                {recent.length === 0 ? (
                    <div className="py-10 text-center text-sm text-ink-faint">
                        아직 등록된 케이스가 없습니다.
                    </div>
                ) : (
                    <div className="divide-y divide-border">
                        {recent.map((batch) => (
                            <Link
                                key={batch.id}
                                to={`/batches/${batch.id}`}
                                className="flex items-center gap-4 py-4 transition-colors hover:bg-brand-soft/50"
                            >
                                <span className="min-w-0 flex-1 truncate text-[15px]">
                                    {batch.patient_summary
                                        ? patientBrief(batch.patient_summary)
                                        : '환자 미연결'}
                                </span>
                                <span className="font-mono text-sm tabular-nums text-ink-muted">
                                    슬라이드 {getJobsByBatch(batch.id).length}
                                </span>
                                <BatchStatusBadge status={batch.status} />
                                <span className="w-24 text-right text-sm text-ink-muted">
                                    {new Date(batch.created_at).toLocaleString('ko-KR', {
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