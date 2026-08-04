import { Link, useParams } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';

import { getImage, getJob } from '@/api';
import type { ClassComposition } from '@/api/types';
import { IntervalAxis } from '@/components/IntervalAxis';
import { IntervalBar } from '@/components/IntervalBar';
import { SlideViewer } from '@/components/SlideViewer';
import { DecisionBadge, JobStatusBadge } from '@/components/StatusBadge';
import { toIntervalView } from '@/lib/decision';
import { patientFull } from '@/lib/patient';

const COMPOSITION_ROWS: { key: keyof ClassComposition; label: string; color: string }[] = [
    { key: 'tumor', label: '종양', color: 'var(--seg-tumor)' },
    { key: 'stroma', label: '기질', color: 'var(--seg-stroma)' },
    { key: 'immune', label: '림프구', color: 'var(--seg-tils)' },
    { key: 'necrosis', label: '괴사', color: 'var(--ink-faint)' },
    { key: 'other', label: '기타', color: 'var(--border-strong)' },
];

export default function ResultDetailPage() {
    const { jobId } = useParams();
    const job = jobId ? getJob(jobId) : undefined;

    if (!job) {
        return (
            <div className="p-6">
                <BackLink />
                <div className="py-16 text-center text-sm text-ink-faint">
                    해당 분석 결과를 찾을 수 없습니다.
                </div>
            </div>
        );
    }

    const filename = getImage(job.image)?.original_filename ?? job.id.slice(0, 8);
    const result = job.result;

    return (
        <div className="p-6">
            <BackLink />

            <div className="mb-6 flex items-start justify-between gap-4">
                <div className="min-w-0">
                    <h1 className="truncate text-xl font-semibold">
                        {job.patient_summary
                            ? patientFull(job.patient_summary)
                            : '환자 미연결'}
                    </h1>
                    <p className="mt-1.5 truncate text-[15px] text-ink-muted" title={filename}>
                        {filename}
                    </p>
                    <p className="mt-1 font-mono text-xs text-ink-faint">{job.id}</p>
                </div>
                <div className="flex shrink-0 gap-2">
                    {result && <DecisionBadge decision={result.decision} />}
                    <JobStatusBadge status={job.status} />
                </div>
            </div>

            {!result ? (
                <div className="rounded-lg border border-border py-16 text-center text-sm text-ink-faint">
                    {job.status === 'failed'
                        ? job.error_message || '분석에 실패했습니다.'
                        : '분석이 진행 중입니다.'}
                </div>
            ) : (
                <div className="grid gap-6 lg:grid-cols-[minmax(0,3fr)_minmax(0,2fr)]">
                    <SlideViewer />

                    <div className="space-y-6">
                        <section>
                            <div className="font-mono text-4xl tabular-nums">
                                {result.stil_value.toFixed(1)}
                                <span className="ml-1 text-lg text-ink-muted">%</span>
                            </div>
                            <div className="mt-3">
                                <IntervalAxis
                                    cutoff={toIntervalView(result).cutoff}
                                    gridClassName="grid grid-cols-1"
                                    axisColStart={1}
                                >
                                    <IntervalBar view={toIntervalView(result)} decision={result.decision} />
                                </IntervalAxis>
                            </div>
                            <div className="mt-2 flex justify-between font-mono text-xs tabular-nums text-ink-muted">
                                <span>{result.lower.toFixed(1)}</span>
                                <span>예측 구간</span>
                                <span>{result.upper.toFixed(1)}</span>
                            </div>
                        </section>

                        <section>
                            <h2 className="mb-3 text-sm font-medium">조직 구성</h2>

                            <div className="mb-3 flex h-2.5 overflow-hidden rounded-full">
                                {COMPOSITION_ROWS.map((row) => (
                                    <div
                                        key={row.key}
                                        style={{
                                            width: `${result.class_composition[row.key]}%`,
                                            backgroundColor: row.color,
                                        }}
                                    />
                                ))}
                            </div>

                            <dl className="space-y-1.5 text-sm">
                                {COMPOSITION_ROWS.map((row) => (
                                    <div key={row.key} className="flex items-center gap-2">
                                        <span
                                            className="size-2.5 shrink-0 rounded-sm"
                                            style={{ backgroundColor: row.color }}
                                        />
                                        <dt className="flex-1 text-ink-muted">{row.label}</dt>
                                        <dd className="font-mono tabular-nums">
                                            {result.class_composition[row.key].toFixed(1)}%
                                        </dd>
                                    </div>
                                ))}
                            </dl>
                        </section>

                        <section>
                            <h2 className="mb-3 text-sm font-medium">불확실성</h2>
                            <dl className="grid grid-cols-2 gap-y-2 text-sm">
                                <dt className="text-ink-muted">σ</dt>
                                <dd className="text-right font-mono tabular-nums">
                                    {result.sigma.toFixed(1)}
                                </dd>
                                <dt className="text-ink-muted">cp_value</dt>
                                <dd className="text-right font-mono tabular-nums">
                                    {result.cp_value}
                                </dd>
                                <dt className="text-ink-muted">유효 타일</dt>
                                <dd className="text-right font-mono tabular-nums">
                                    {result.n_valid}
                                </dd>
                            </dl>
                        </section>

                        <section>
                            <h2 className="mb-3 text-sm font-medium">판독 리포트</h2>
                            {!result.medgemma_report ? (
                                <p className="text-sm text-ink-faint">
                                    리포트를 작성하고 있습니다.
                                </p>
                            ) : result.medgemma_report.generation_failed ? (
                                <p className="text-sm text-ink-faint">
                                    리포트 생성에 실패했습니다.
                                </p>
                            ) : (
                                <p className="text-sm leading-relaxed">
                                    {result.medgemma_report.summary}
                                </p>
                            )}
                        </section>
                    </div>
                </div>
            )}
        </div>
    );
}

function BackLink() {
    return (
        <Link
            to="/review"
            className="mb-4 inline-flex items-center gap-1.5 text-sm text-ink-muted transition-colors hover:text-ink"
        >
            <ArrowLeft size={15} />
            판정 유보 검증함
        </Link>
    );
}
