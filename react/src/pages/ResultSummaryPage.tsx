import { useState } from 'react';
import { Link, useParams } from 'react-router-dom';

import { getBatch, getImage, getJobsByBatch, getModelVersions } from '@/api';
import type { Job, JobResult } from '@/api/types';
import { AXIS_GRID, IntervalAxis } from '@/components/IntervalAxis';
import { IntervalBar } from '@/components/IntervalBar';
import { DecisionBadge, JobStatusBadge } from '@/components/StatusBadge';
import { Card, CardContent } from '@/components/ui/card';
import type { IntervalView } from '@/lib/decision';
import { CUTOFF, classifyAt, toIntervalView } from '@/lib/decision';
import { BATCH_STATUS_LABEL } from '@/lib/jobStatus';
import { patientFull } from '@/lib/patient';

interface Row {
    job : Job;
    result : JobResult | null;
    view : IntervalView | null;
    filename : string;
}

export default function ResultSummaryPage() {
    const { batchId } = useParams();
    const [cutoff, setCutoff] = useState(CUTOFF);

    const batch = batchId ? getBatch(batchId) : undefined;

    if (!batch) {
        return (
            <div className="py-16 text-center text-sm text-ink-faint">
                해당 배치를 찾을 수 없습니다.
            </div>
        );
    }

    const rows : Row[] = getJobsByBatch(batch.id).map((job) => ({
        job,
        result: job.result,
        view: job.result ? toIntervalView(job.result, cutoff) : null,
        filename: getImage(job.image)?.original_filename ?? job.id.slice(0, 8),
    }));

    const total = rows.length;
    const failed = rows.filter((r) => r.job.status === 'failed').length;
    const done = rows.filter((r) => r.job.status === 'succeeded').length;
    const review = rows.filter((r) => r.view?.crossesCutoff).length;

    const modelName =
        getModelVersions().find((m) => m.id === rows[0]?.job.model_version)?.name ?? '-';

    return (
        <div>
            <div className="mb-6">
                <div className="flex items-baseline gap-3">
                    <h1 className="text-xl font-semibold">
                        {batch.patient_summary
                            ? patientFull(batch.patient_summary)
                            : '환자 미연결'}
                    </h1>
                    <span className="text-[15px] text-ink-muted">
                        {BATCH_STATUS_LABEL[batch.status]}
                    </span>
                </div>
                <p className="mt-1.5 font-mono text-sm text-ink-faint">
                    {batch.id.slice(0, 8)} · {modelName} ·{' '}
                    {new Date(batch.created_at).toLocaleString('ko-KR')}
                </p>
            </div>

            <div className="mb-8 grid grid-cols-2 gap-3 md:grid-cols-4">
                <SummaryCard label="전체" value={total} />
                <SummaryCard label="확인 필요" value={review} accent />
                <SummaryCard label="완료" value={done} />
                <SummaryCard label="실패" value={failed} />
            </div>

            {total === 0 ? (
                <div className="py-16 text-center text-sm text-ink-faint">
                    이 배치에는 분석이 없습니다.
                </div>
            ) : (
                <IntervalAxis
                    cutoff={cutoff}
                    onCutoffChange={setCutoff}
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
                        {rows.map((row) => (
                            <SlideRow key={row.job.id} row={row} cutoff={cutoff} />
                        ))}
                    </div>
                </IntervalAxis>
            )}
        </div>
    );
}

function SummaryCard({
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
                    className={`mt-1.5 font-mono text-3xl tabular-nums ${
                        accent && value > 0 ? 'text-decision-abstain' : ''
                    }`}
                >
                    {value}
                </div>
            </CardContent>
        </Card>
    );
}

// 결과가 없는 job은 막대 대신 상태나 실패 사유를 보인다
function SlideRow({ row, cutoff } : { row : Row; cutoff : number }) {
    const body =
        row.result && row.view ? (
            <Link
                to={`/results/${row.job.id}`}
                className={`${AXIS_GRID} w-full py-4 transition-colors hover:bg-brand-soft/50`}
            >
                <span className="truncate text-[15px]" title={row.filename}>
                    {row.filename}
                </span>

                <IntervalBar view={row.view} decision={classifyAt(row.result, cutoff)} />

                <span className="text-right font-mono text-base tabular-nums">
                    {row.result.stil_value.toFixed(1)}
                </span>
                <span className="text-right font-mono text-sm tabular-nums text-ink-muted">
                    {row.result.sigma.toFixed(1)}
                </span>

                <span className="flex justify-end">
                    <DecisionBadge decision={classifyAt(row.result, cutoff)} />
                </span>
            </Link>
        ) : (
            <div className={`${AXIS_GRID} w-full py-4`}>
                <span className="truncate text-[15px]" title={row.filename}>
                    {row.filename}
                </span>

                <span className="truncate text-sm text-ink-faint">
                    {row.job.status === 'failed'
                        ? row.job.error_message || '분석에 실패했습니다.'
                        : '분석 대기 중입니다.'}
                </span>

                <span />
                <span />

                <span className="flex justify-end">
                    <JobStatusBadge status={row.job.status} />
                </span>
            </div>
        );

    return body;
}
