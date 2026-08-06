// 09 판정 유보 검증함
import { useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import { createJobReview, getLatestJobs, getMe } from '@/api';
import { qk } from '@/api/keys';
import type { Job, JobResult, ReviewDecision } from '@/api/types';
import { AXIS_GRID, IntervalAxis } from '@/components/IntervalAxis';
import { ClinicalNotice } from '@/components/ClinicalNotice';
import { BUTTON_PRIMARY, FIELD_INPUT } from '@/components/form';
import { IntervalBar } from '@/components/IntervalBar';
import { Empty, Failed, Pending } from '@/components/QueryState';
import { ConfirmedDecision, DecisionBadge } from '@/components/StatusBadge';
import { Card, CardContent } from '@/components/ui/card';
import {
    Sheet,
    SheetContent,
    SheetHeader,
    SheetTitle,
} from '@/components/ui/sheet';
import type { IntervalView } from '@/lib/decision';
import { CUTOFF, DECISION_LABEL, needsReview, toIntervalView } from '@/lib/decision';
import { formatShort } from '@/lib/format';
import { patientLabel, patientLabelFull } from '@/lib/patient';
import { cn } from '@/lib/utils';

interface Row {
    job : Job;
    result : JobResult;
    view : IntervalView;
    filename : string;
}

// 결과가 나온 job만, σ 내림차순
function buildRows(jobs : Job[]) : Row[] {
    return jobs
        .filter((j) => j.status === 'succeeded' || j.status === 'stil_done')
        .flatMap((job) => {
            if (!job.result) return [];
            return [{
                job,
                result: job.result,
                view: toIntervalView(job.result),
                filename: job.image_summary?.original_filename ?? job.id.slice(0, 8),
            }];
        })
        .sort((a, b) => b.result.sigma - a.result.sigma);
}

export default function AbstainReviewPage() {
    const [searchParams, setSearchParams] = useSearchParams();

    const jobs = useQuery({ queryKey: qk.latestJobs, queryFn: getLatestJobs });

    const selectedId = searchParams.get('job');

    function select(id : string | null) {
        const next = new URLSearchParams(searchParams);
        if (id) next.set('job', id);
        else next.delete('job');
        setSearchParams(next, { replace: true });
    }

    if (jobs.isPending) return <Pending />;
    if (jobs.isError) return <Failed error={jobs.error} onRetry={() => void jobs.refetch()} />;

    const rows = buildRows(jobs.data);
    const reviewCount = rows.filter((r) => needsReview(r.job)).length;
    const selected = rows.find((r) => r.job.id === selectedId) ?? null;

    return (
        <div>
            <div className="mb-2 text-base text-ink-muted">
                결과 {rows.length}건 중{' '}
                <span className="font-semibold text-decision-abstain">
                    확인 필요 {reviewCount}건
                </span>
            </div>

            <ClinicalNotice className="mb-6" />

            {rows.length === 0 ? (
                <Empty label="판독 결과가 없습니다" />
            ) : reviewCount === 0 ? (
                <Empty label="확인이 필요한 기권 케이스가 없습니다" />
            ) : rows.length <= 3 ? (
                <CardLayout rows={rows} onSelect={select} />
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
                    <SlideRows rows={rows} onSelect={select} />
                </IntervalAxis>
            )}

            <DetailSheet row={selected} onClose={() => select(null)} />
        </div>
    );
}

function SlideRows({
    rows,
    onSelect,
} : {
    rows : Row[];
    onSelect : (id : string) => void;
}) {
    return (
        <div className="divide-y divide-border">
            {rows.map((row) => (
                <button
                    key={row.job.id}
                    type="button"
                    onClick={() => onSelect(row.job.id)}
                    className={`${AXIS_GRID} w-full py-4 text-left transition-colors hover:bg-brand-soft/50`}
                >
                    <span className="min-w-0">
                        <span
                            className="block truncate text-base"
                            title={patientLabel(row.job.patient_summary)}
                        >
                            {patientLabel(row.job.patient_summary)}
                        </span>
                        <span
                            className="block truncate text-sm text-ink-faint"
                            title={row.filename}
                        >
                            {row.filename}
                        </span>
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
                </button>
            ))}
        </div>
    );
}

function CardLayout({
    rows,
    onSelect,
} : {
    rows : Row[];
    onSelect : (id : string) => void;
}) {
    return (
        <div className="grid gap-4 md:grid-cols-2">
            {rows.map((row) => (
                <button
                    key={row.job.id}
                    type="button"
                    onClick={() => onSelect(row.job.id)}
                    className="w-full text-left"
                >
                    <Card className="transition hover:bg-brand-soft/25 hover:ring-brand/30">
                        <CardContent className="space-y-4">
                            <div className="flex items-start justify-between gap-2">
                                <span className="min-w-0">
                                    <span
                                        className="block truncate text-base"
                                        title={patientLabel(row.job.patient_summary)}
                                    >
                                        {patientLabel(row.job.patient_summary)}
                                    </span>
                                    <span
                                        className="block truncate text-sm text-ink-faint"
                                        title={row.filename}
                                    >
                                        {row.filename}
                                    </span>
                                </span>
                                {row.job.review ? (
                                    <ConfirmedDecision
                                        decision={row.result.decision}
                                        review={row.job.review}
                                    />
                                ) : (
                                    <DecisionBadge decision={row.result.decision} />
                                )}
                            </div>

                            <div className="font-mono text-3xl tabular-nums">
                                {row.result.stil_value.toFixed(1)}
                                <span className="ml-1 text-base text-ink-muted">%</span>
                            </div>

                            <IntervalAxis
                                cutoff={CUTOFF}
                                gridClassName="grid grid-cols-1"
                                axisColStart={1}
                            >
                                <IntervalBar view={row.view} decision={row.result.decision} />
                            </IntervalAxis>

                            <div className="flex justify-between text-xs text-ink-muted">
                                <span className="font-mono tabular-nums">
                                    {row.result.lower.toFixed(1)} ~ {row.result.upper.toFixed(1)}
                                </span>
                                <span className="font-mono tabular-nums">
                                    σ {row.result.sigma.toFixed(1)}
                                </span>
                            </div>
                        </CardContent>
                    </Card>
                </button>
            ))}
        </div>
    );
}

const REVIEW_OPTIONS : ReviewDecision[] = ['LOW', 'HIGH'];

function ReviewSection({ job } : { job : Job }) {
    const queryClient = useQueryClient();

    const { data: me } = useQuery({ queryKey: qk.me, queryFn: getMe });

    const [decision, setDecision] = useState<ReviewDecision>('LOW');
    const [reason, setReason] = useState('');

    const confirm = useMutation({
        mutationFn: () => createJobReview(job.id, { decision, reason: reason.trim() }),
        onSuccess: (review) => {
            void queryClient.invalidateQueries({ queryKey: qk.latestJobs });
            void queryClient.invalidateQueries({ queryKey: qk.batches });
            void queryClient.invalidateQueries({ queryKey: qk.job(job.id) });
            setReason('');
            toast.success(`${DECISION_LABEL[review.decision]}으로 확정했습니다`);
        },
        onError: (err : Error) =>
            toast.error('확정하지 못했습니다', { description: err.message }),
    });

    if (job.review) {
        return (
            <div className="rounded-lg border border-border p-3">
                <p className="mb-2 text-xs text-ink-muted">
                    {formatShort(job.review.created_at)} 확정
                </p>
                <p className="whitespace-pre-wrap text-sm leading-relaxed">
                    {job.review.reason}
                </p>
            </div>
        );
    }

    // 서버도 role=doctor만 받는다 (403)
    if (me?.role !== 'doctor') {
        return (
            <p className="rounded-lg border border-border p-3 text-sm text-ink-muted">
                확정은 의사만 할 수 있습니다
            </p>
        );
    }

    return (
        <div className="rounded-lg border border-border p-3">
            <p className="mb-2 text-xs text-ink-muted">판정 확정</p>

            <div className="mb-3 flex items-center gap-0.5 rounded-md border border-border p-0.5">
                {REVIEW_OPTIONS.map((d) => (
                    <button
                        key={d}
                        type="button"
                        onClick={() => setDecision(d)}
                        aria-pressed={decision === d}
                        className={cn(
                            'flex h-8 flex-1 items-center justify-center rounded text-sm transition-colors',
                            decision === d
                                ? 'bg-surface-raised font-medium text-ink shadow-sm'
                                : 'text-ink-muted hover:bg-ink/[0.04] hover:text-ink',
                        )}
                    >
                        {DECISION_LABEL[d]}
                    </button>
                ))}
            </div>

            <textarea
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                rows={3}
                placeholder="판단 근거를 남겨 주세요"
                aria-label="판단 근거"
                className={`${FIELD_INPUT} h-auto resize-y py-2 leading-relaxed`}
            />

            <button
                type="button"
                onClick={() => confirm.mutate()}
                disabled={!reason.trim() || confirm.isPending}
                className={`mt-3 w-full ${BUTTON_PRIMARY}`}
            >
                {DECISION_LABEL[decision]}으로 확정
            </button>
        </div>
    );
}

function DetailSheet({
    row,
    onClose,
} : {
    row : Row | null;
    onClose : () => void;
}) {
    return (
        <Sheet open={!!row} onOpenChange={(open) => !open && onClose()}>
            <SheetContent className="w-full overflow-y-auto sm:max-w-md">
                {row && (
                    <>
                        <SheetHeader>
                            <SheetTitle
                                className="truncate text-base"
                                title={patientLabelFull(row.job.patient_summary)}
                            >
                                {patientLabelFull(row.job.patient_summary)}
                            </SheetTitle>
                            <p className="truncate text-sm text-ink-faint" title={row.filename}>
                                {row.filename}
                            </p>
                        </SheetHeader>

                        {/* 값 · 구간 · 판정. 나머지는 08 결과 상세 */}
                        <div className="space-y-6 px-4 pb-6">
                            {row.job.review ? (
                                <ConfirmedDecision
                                    decision={row.result.decision}
                                    review={row.job.review}
                                />
                            ) : (
                                <DecisionBadge decision={row.result.decision} />
                            )}

                            <div>
                                <div className="font-mono text-4xl tabular-nums">
                                    {row.result.stil_value.toFixed(1)}
                                    <span className="ml-1 text-lg text-ink-muted">%</span>
                                </div>
                                <div className="mt-3">
                                    <IntervalAxis
                                        cutoff={CUTOFF}
                                        gridClassName="grid grid-cols-1"
                                        axisColStart={1}
                                    >
                                        <IntervalBar view={row.view} decision={row.result.decision} />
                                    </IntervalAxis>
                                </div>
                                <div className="mt-2 flex justify-between font-mono text-xs tabular-nums text-ink-muted">
                                    <span>{row.result.lower.toFixed(1)}</span>
                                    <span>예측 구간 · σ {row.result.sigma.toFixed(1)}</span>
                                    <span>{row.result.upper.toFixed(1)}</span>
                                </div>
                            </div>

                            <ReviewSection job={row.job} />

                            <Link
                                to={`/results/${row.job.id}`}
                                className="inline-flex h-10 items-center rounded-md border border-border px-4 text-sm transition-colors hover:bg-brand-soft"
                            >
                                전체 화면으로
                            </Link>
                        </div>
                    </>
                )}
            </SheetContent>
        </Sheet>
    );
}
