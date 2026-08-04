// 08 결과 상세
import { useNavigate, useParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Copy } from 'lucide-react';
import { toast } from 'sonner';

import { getJob, retryJob } from '@/api';
import { qk } from '@/api/keys';
import type { ClassComposition } from '@/api/types';
import { BUTTON_SECONDARY, ICON_BUTTON } from '@/components/form';
import { IntervalAxis } from '@/components/IntervalAxis';
import { ClinicalNotice } from '@/components/ClinicalNotice';
import { IntervalBar } from '@/components/IntervalBar';
import { Failed, Pending } from '@/components/QueryState';
import { SlideViewer } from '@/components/SlideViewer';
import { DecisionBadge, JobStatusBadge } from '@/components/StatusBadge';
import { toIntervalView } from '@/lib/decision';

// 분석 ID >> 접어 두고 복사만
function JobId({ id } : { id : string }) {
    async function copy() {
        try {
            await navigator.clipboard.writeText(id);
            toast('분석 ID를 복사했습니다');
        } catch {
            toast('복사하지 못했습니다', { description: id });
        }
    }

    return (
        <details className="min-w-0">
            <summary className="cursor-pointer text-xs text-ink-faint transition-colors hover:text-ink-muted">
                분석 ID
            </summary>

            <div className="mt-1.5 flex items-center gap-2">
                <code className="truncate font-mono text-xs text-ink-faint">{id}</code>
                <button
                    type="button"
                    onClick={() => void copy()}
                    aria-label="분석 ID 복사"
                    className={`shrink-0 ${ICON_BUTTON}`}
                >
                    <Copy size={13} />
                </button>
            </div>
        </details>
    );
}

const COMPOSITION_ROWS: { key: keyof ClassComposition; label: string; color: string }[] = [
    { key: 'tumor', label: '종양', color: 'var(--seg-tumor)' },
    { key: 'stroma', label: '기질', color: 'var(--seg-stroma)' },
    { key: 'immune', label: '림프구', color: 'var(--seg-tils)' },
    { key: 'necrosis', label: '괴사', color: 'var(--ink-faint)' },
    { key: 'other', label: '기타', color: 'var(--border-strong)' },
];

export default function ResultDetailPage() {
    const { jobId } = useParams();
    const navigate = useNavigate();
    const queryClient = useQueryClient();

    const { data: job, isPending, isError, error, refetch } = useQuery({
        queryKey: qk.job(jobId ?? ''),
        queryFn: () => getJob(jobId!),
        enabled: !!jobId,
        // 결과가 붙을 때까지 폴링
        refetchInterval: (query) => (query.state.data?.result ? false : 2000),
    });

    const retry = useMutation({
        mutationFn: (imageId : string) => retryJob(imageId),
        onSuccess: (next) => {
            void queryClient.invalidateQueries({ queryKey: qk.latestJobs });
            toast('다시 분석을 요청했습니다');
            navigate(`/results/${next.id}`, { replace: true });
        },
        onError: (err : Error) =>
            toast('다시 요청하지 못했습니다', { description: err.message }),
    });

    if (isPending) return <Pending />;
    if (isError) return <Failed error={error} onRetry={() => void refetch()} />;

    const result = job.result;

    return (
        <div>
            {/* 환자·파일명은 브레드크럼 */}
            <div className="mb-6 flex items-start justify-between gap-4">
                <JobId id={job.id} />

                <div className="flex shrink-0 gap-2">
                    {result && <DecisionBadge decision={result.decision} />}
                    <JobStatusBadge status={job.status} />
                </div>
            </div>

            {!result ? (
                <div className="rounded-lg border border-border py-16 text-center">
                    <p className="text-sm text-ink-faint">
                        {job.status === 'failed'
                            ? job.error_message || '분석에 실패했습니다.'
                            : '분석 중'}
                    </p>

                    {/* 실패했으면 여기서 바로 다시 건다. 배치로 되돌아갈 이유가 없다 */}
                    {job.status === 'failed' && (
                        <button
                            type="button"
                            onClick={() => retry.mutate(job.image)}
                            disabled={retry.isPending}
                            className={`mt-4 ${BUTTON_SECONDARY}`}
                        >
                            재실행
                        </button>
                    )}
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

                            <ClinicalNotice className="mt-4" />
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
                            </dl>

                            {/* cp_value · 유효 타일 >> 모델 진단용 */}
                            <details className="mt-2 text-sm">
                                <summary className="cursor-pointer text-xs text-ink-faint transition-colors hover:text-ink-muted">
                                    계산 근거
                                </summary>
                                <dl className="mt-2 grid grid-cols-2 gap-y-2">
                                    <dt className="text-ink-muted">cp_value</dt>
                                    <dd className="text-right font-mono tabular-nums">
                                        {result.cp_value}
                                    </dd>
                                    <dt className="text-ink-muted">유효 타일</dt>
                                    <dd className="text-right font-mono tabular-nums">
                                        {result.n_valid}
                                    </dd>
                                </dl>
                            </details>
                        </section>
                    </div>
                </div>
            )}
        </div>
    );
}

