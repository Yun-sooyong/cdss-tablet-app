import { Link } from 'react-router-dom';
import { ArrowRight } from 'lucide-react';

import { getBatches, getImage, getJobs, getJobsByBatch } from '@/api';
import { AXIS_GRID, IntervalAxis } from '@/components/IntervalAxis';
import { IntervalBar } from '@/components/IntervalBar';
import { BatchStatusBadge, DecisionBadge } from '@/components/StatusBadge';
import { Card, CardContent } from '@/components/ui/card';
import { CUTOFF, needsReview, toIntervalView } from '@/lib/decision';
import { patientBrief } from '@/lib/patient';
import { cn } from '@/lib/utils';

const PREVIEW_COUNT = 5;

export default function DashboardPage() {
    const jobs = getJobs();

    const review = jobs.filter((j) => needsReview(j.result));
    const running = jobs.filter(
        (j) => j.status === 'queued' || j.status === 'running' || j.status === 'stil_done',
    ).length;
    const done = jobs.filter((j) => j.status === 'succeeded').length;
    const failed = jobs.filter((j) => j.status === 'failed').length;

    return (
        <div className="p-6">
            <h1 className="mb-6 text-xl font-semibold">대시보드</h1>

            <div className = "mb-8 grid-cols-2 gap-3 md:grid-cols-4">
                <KpiCard label="확인 필요" value={review.length} accent />
                <KpiCard label="진행 중" value={running} />
                <KpiCard label="완료" value={done} />
                <KpiCard label="실패" value={failed} />
            </div>

            <section className = "mb-8">
                    {review.length === 0 ? (
        <div className="py-10 text-center text-sm text-ink-faint">
            확인이 필요한 케이스가 없습니다.
        </div>
    ) : (
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
                            className={cn(AXIS_GRID, 'py-4 transition-colors hover:bg-brand-soft/50')}
                        >
                            <span className="min-w-0">
                                <span className="block truncate text-[15px]">
                                    {job.patient_summary
                                        ? patientBrief(job.patient_summary)
                                        : '환자 미연결'}
                                </span>
                                <span className="block truncate text-[13px] text-ink-faint">
                                    {getImage(job.image)?.original_filename ?? job.id.slice(0, 8)}
                                </span>
                            </span>

                            <IntervalBar view={toIntervalView(result)} decision={result.decision} />

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
    )}
        </section>
        <section>
             <SectionHeader title="최근 케이스" to="/cases" />

    <div className="divide-y divide-border">
        {getBatches()
            .slice()
            .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
            .slice(0, PREVIEW_COUNT)
            .map((batch) => (
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
        </section>    
        </div>
    );
}

function KpiCard({
    label,
    value,
    accent,
} : {
    label : string;
    value : number;
    accent? : boolean;
}) {
    return (
        <Card>
            <CardContent className="py-4">
                <div className="text-sm text-ink-muted">{label}</div>
                <div
                    className={cn(
                        'mt-1.5 font-mono text-3xl tabular-nums',
                        accent && value > 0 && 'text-decision-abstain',
                    )}
                >
                    {value}
                </div>
            </CardContent>
        </Card>
    );
}

function SectionHeader({ title, to } : { title : string; to : string }) {
    return (
        <div className="mb-3 flex items-baseline justify-between">
            <h2 className="text-base font-medium">{title}</h2>
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
