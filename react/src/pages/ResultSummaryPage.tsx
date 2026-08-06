// 07 배치 요약
import { Link, useParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { RotateCcw } from 'lucide-react';
import { toast } from 'sonner';

import { getBatchDetail, getModelVersions, latestPerImage, retryJob } from '@/api';
import { qk } from '@/api/keys';
import type { Job, JobResult } from '@/api/types';
import { BUTTON_QUIET } from '@/components/form';
import { AXIS_GRID, IntervalAxis } from '@/components/IntervalAxis';
import { IntervalBar } from '@/components/IntervalBar';
import { Empty, Failed, Pending } from '@/components/QueryState';
import { ConfirmedDecision, DecisionBadge, JobStatusBadge } from '@/components/StatusBadge';
import { stalledBatchIds, useUploads } from '@/components/upload/context';
import { CUTOFF, toIntervalView } from '@/lib/decision';
import type { IntervalView } from '@/lib/decision';
import { BATCH_STATUS_LABEL, isBatchTerminal } from '@/lib/jobStatus';
import { patientLabelFull } from '@/lib/patient';

interface Row {
    job : Job;
    result : JobResult | null;
    view : IntervalView | null;
    filename : string;
}

export default function ResultSummaryPage() {
    const { batchId } = useParams();
    const queryClient = useQueryClient();
    const { items } = useUploads();
    const stalled = !!batchId && stalledBatchIds(items).has(batchId);

    const batch = useQuery({
        queryKey: qk.batch(batchId ?? ''),
        queryFn: () => getBatchDetail(batchId!),
        enabled: !!batchId,
        // 종료 전까지 폴링
        refetchInterval: (query) =>
            query.state.data && isBatchTerminal(query.state.data.status) ? false : 2000,
    });

    const { data: models } = useQuery({
        queryKey: qk.modelVersions,
        queryFn: getModelVersions,
    });

    const retry = useMutation({
        mutationFn: (imageId : string) => retryJob(imageId),
        onSuccess: () => {
            void queryClient.invalidateQueries({ queryKey: qk.batch(batchId ?? '') });
            void queryClient.invalidateQueries({ queryKey: qk.batches });
            void queryClient.invalidateQueries({ queryKey: qk.latestJobs });
            toast.success('다시 분석을 요청했습니다');
        },
        onError: (error : Error) =>
            toast.error('다시 요청하지 못했습니다', { description: error.message }),
    });

    if (batch.isPending) return <Pending />;
    if (batch.isError) return <Failed error={batch.error} onRetry={() => void batch.refetch()} />;

    const modelNameById = new Map((models ?? []).map((m) => [m.id, m.name]));

    const rows : Row[] = latestPerImage(batch.data.jobs).map((job) => ({
        job,
        result: job.result,
        view: job.result ? toIntervalView(job.result) : null,
        filename: job.image_summary?.original_filename ?? job.id.slice(0, 8),
    }));

    // 배치 안에 모델이 섞일 수 있다
    const modelNames = [...new Set(rows.map((r) => r.job.model_version))]
        .map((id) => modelNameById.get(id))
        .filter((name) : name is string => !!name);

    const modelLabel =
        modelNames.length === 0
            ? '-'
            : modelNames.length === 1
              ? modelNames[0]
              : `${modelNames[0]} 외 ${modelNames.length - 1}`;

    return (
        <div>
            <div className="mb-6">
                <p className="text-[15px]" title={patientLabelFull(batch.data.patient_summary)}>
                    {patientLabelFull(batch.data.patient_summary)}
                </p>

                <div className="mt-1 flex flex-wrap items-baseline gap-x-3 gap-y-1">
                    <span className="text-sm text-ink-muted">
                        {BATCH_STATUS_LABEL[batch.data.status]}
                    </span>
                    <span
                        className="font-mono text-sm text-ink-faint"
                        title={modelNames.join(' · ')}
                    >
                        {modelLabel} · {new Date(batch.data.created_at).toLocaleString('ko-KR')}
                    </span>
                </div>
            </div>

            {rows.length === 0 ? (
                stalled ? (
                    <div role="alert" className="py-16 text-center text-sm">
                        <p className="text-danger">업로드에 실패한 슬라이드가 있습니다</p>
                        <p className="mt-1 text-ink-faint">
                            헤더의 업로드 표시에서 재시도해야 분석이 시작됩니다
                        </p>
                    </div>
                ) : (
                    <Empty
                        label={
                            batch.data.status === 'pending'
                                ? '업로드가 끝나면 분석이 시작됩니다'
                                : '분석된 슬라이드가 없습니다'
                        }
                    />
                )
            ) : (
                // 컷오프 고정. 슬라이더는 09 판정 유보 검증함
                <IntervalAxis
                    cutoff={CUTOFF}
                    leading={<span>슬라이드</span>}
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
                            <SlideRow
                                key={row.job.id}
                                row={row}
                                onRetry={() => retry.mutate(row.job.image)}
                                retrying={retry.isPending}
                            />
                        ))}
                    </div>
                </IntervalAxis>
            )}
        </div>
    );
}

// 결과 있으면 막대, 없으면 상태·실패 사유
function SlideRow({
    row,
    onRetry,
    retrying,
} : {
    row : Row;
    onRetry : () => void;
    retrying : boolean;
}) {
    if (row.result && row.view) {
        return (
            <Link
                to={`/results/${row.job.id}`}
                className={`${AXIS_GRID} w-full py-4 transition-colors hover:bg-brand-soft/50`}
            >
                <span className="truncate text-[15px]" title={row.filename}>
                    {row.filename}
                </span>

                <IntervalBar view={row.view} decision={row.result.decision} />

                <span className="text-right font-mono text-base tabular-nums">
                    {row.result.stil_value.toFixed(1)}
                </span>
                <span className="text-right font-mono text-sm tabular-nums text-ink-muted">
                    {row.result.sigma.toFixed(1)}
                </span>

                <span className="flex justify-end">
                    {row.job.review ? (
                        <ConfirmedDecision
                            decision={row.result.decision}
                            review={row.job.review}
                            className="justify-end"
                        />
                    ) : (
                        <DecisionBadge decision={row.result.decision} />
                    )}
                </span>
            </Link>
        );
    }

    const failed = row.job.status === 'failed';

    return (
        <div className={`${AXIS_GRID} w-full py-4`}>
            <span className="truncate text-[15px]" title={row.filename}>
                {row.filename}
            </span>

            <span className="truncate text-sm text-ink-faint">
                {failed ? row.job.error_message || '분석에 실패했습니다.' : '대기'}
            </span>

            <span />
            <span />

            <span className="flex items-center justify-end gap-2">
                {failed && (
                    <button
                        type="button"
                        onClick={onRetry}
                        disabled={retrying}
                        className={BUTTON_QUIET}
                    >
                        <RotateCcw size={12} />
                        재실행
                    </button>
                )}

                <JobStatusBadge status={row.job.status} />
            </span>
        </div>
    );
}
