import { useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';

import { getImage, getJobs } from '@/api';
import type { Job, JobResult } from '@/api/types';
import { AXIS_GRID, IntervalAxis } from '@/components/IntervalAxis';
import { IntervalBar } from '@/components/IntervalBar';
import { DecisionBadge, JobStatusBadge } from '@/components/StatusBadge';
import { Card, CardContent } from '@/components/ui/card';
import {
    Sheet,
    SheetContent,
    SheetHeader,
    SheetTitle,
} from '@/components/ui/sheet';
import type { IntervalView } from '@/lib/decision';
import { CUTOFF, classifyAt, toIntervalView } from '@/lib/decision';
import { patientBrief, patientFull } from '@/lib/patient';

interface Row {
    job : Job;
    result : JobResult;
    view : IntervalView;
    filename : string;
}

// 결과가 나온 것만
function buildRows(cutoff : number) : Row[] {
    return getJobs()
        .filter((j) => j.status === 'succeeded' || j.status === 'stil_done')
        .flatMap((job) => {
            if (!job.result) return [];
            return [{
                job,
                result: job.result,
                view: toIntervalView(job.result, cutoff),
                filename: getImage(job.image)?.original_filename ?? job.id.slice(0, 8),
            }];
        })
        // ABSTAIN 먼저, 그다음 구간 넓은 순
        .sort((a, b) => {
            const aRank = a.view.crossesCutoff ? 0 : 1;
            const bRank = b.view.crossesCutoff ? 0 : 1;
            if (aRank !== bRank) return aRank - bRank;
            return b.view.width - a.view.width;
        });
}

export default function AbstainReviewPage() {
    const [searchParams, setSearchParams] = useSearchParams();
    const [cutoff, setCutoff] = useState(CUTOFF);

    const rows = buildRows(cutoff);
    const reviewCount = rows.filter((r) => r.view.crossesCutoff).length;

    const selectedId = searchParams.get('job');
    const selected = rows.find((r) => r.job.id === selectedId) ?? null;

    function select(id : string | null) {
        const next = new URLSearchParams(searchParams);
        if (id) next.set('job', id);
        else next.delete('job');
        setSearchParams(next, { replace: true });
    }

    return (
        <div className="p-6">
            <div className="mb-6 flex items-baseline justify-between">
                <h1 className="text-xl font-semibold">판정 유보 검증함</h1>
                <div className="text-[15px] text-ink-muted">
                    결과 {rows.length}건 중{' '}
                    <span className="font-semibold text-decision-abstain">
                        확인 필요 {reviewCount}건
                    </span>
                </div>
            </div>

            {rows.length === 0 ? (
                <div className="py-16 text-center text-sm text-ink-faint">
                    아직 결과가 없습니다.
                </div>
            ) : rows.length <= 3 ? (
                <CardLayout rows={rows} cutoff={cutoff} onSelect={select} />
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
                    <SlideRows rows={rows} cutoff={cutoff} onSelect={select} />
                </IntervalAxis>
            )}

            <DetailSheet row={selected} cutoff={cutoff} onClose={() => select(null)} />
        </div>
    );
}

export function SlideRows({
    rows,
    cutoff,
    onSelect,
} : {
    rows : Row[];
    cutoff : number;
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
                        <span className="block truncate text-[15px]">
                            {row.job.patient_summary
                                ? patientBrief(row.job.patient_summary)
                                : '환자 미연결'}
                        </span>
                        <span
                            className="block truncate text-[13px] text-ink-faint"
                            title={row.filename}
                        >
                            {row.filename}
                        </span>
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
                </button>
            ))}
        </div>
    );
}

// 3건 이하는 축 하나에 막대가 한둘만 놓여 빈약하다
function CardLayout({
    rows,
    cutoff,
    onSelect,
} : {
    rows : Row[];
    cutoff : number;
    onSelect : (id : string) => void;
}) {
    return (
        <div className="grid gap-4 md:grid-cols-2">
            {rows.map((row) => (
                <Card
                    key={row.job.id}
                    onClick={() => onSelect(row.job.id)}
                    className="cursor-pointer transition-colors hover:border-border-strong"
                >
                    <CardContent className="space-y-4">
                        <div className="flex items-start justify-between gap-2">
                            <span className="min-w-0">
                                <span className="block truncate text-[15px]">
                                    {row.job.patient_summary
                                        ? patientBrief(row.job.patient_summary)
                                        : '환자 미연결'}
                                </span>
                                <span
                                    className="block truncate text-[13px] text-ink-faint"
                                    title={row.filename}
                                >
                                    {row.filename}
                                </span>
                            </span>
                            <DecisionBadge decision={classifyAt(row.result, cutoff)} />
                        </div>

                        <div className="font-mono text-3xl tabular-nums">
                            {row.result.stil_value.toFixed(1)}
                            <span className="ml-1 text-base text-ink-muted">%</span>
                        </div>

                        <IntervalAxis
                            cutoff={cutoff}
                            gridClassName="grid grid-cols-1"
                            axisColStart={1}
                        >
                            <IntervalBar view={row.view} decision={classifyAt(row.result, cutoff)} />
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
            ))}
        </div>
    );
}

function DetailSheet({
    row,
    cutoff,
    onClose,
} : {
    row : Row | null;
    cutoff : number;
    onClose : () => void;
}) {
    return (
        <Sheet open={!!row} onOpenChange={(open) => !open && onClose()}>
            <SheetContent className="w-full overflow-y-auto sm:max-w-md">
                {row && (
                    <>
                        <SheetHeader>
                            <SheetTitle className="truncate text-base">
                                {row.job.patient_summary
                                    ? patientFull(row.job.patient_summary)
                                    : '환자 미연결'}
                            </SheetTitle>
                            <p className="truncate text-sm text-ink-faint" title={row.filename}>
                                {row.filename}
                            </p>
                        </SheetHeader>

                        <div className="space-y-6 px-4 pb-6">
                            <div className="flex gap-2">
                                <DecisionBadge decision={classifyAt(row.result, cutoff)} />
                                <JobStatusBadge status={row.job.status} />
                            </div>

                            <div>
                                <div className="font-mono text-4xl tabular-nums">
                                    {row.result.stil_value.toFixed(1)}
                                    <span className="ml-1 text-lg text-ink-muted">%</span>
                                </div>
                                <div className="mt-3">
                                    <IntervalAxis
                                        cutoff={cutoff}
                                        gridClassName="grid grid-cols-1"
                                        axisColStart={1}
                                    >
                                        <IntervalBar view={row.view} decision={classifyAt(row.result, cutoff)} />
                                    </IntervalAxis>
                                </div>
                            </div>

                            <dl className="grid grid-cols-2 gap-y-2 text-sm">
                                <dt className="text-ink-muted">예측 구간</dt>
                                <dd className="text-right font-mono tabular-nums">
                                    {row.result.lower.toFixed(1)} ~ {row.result.upper.toFixed(1)}
                                </dd>
                                <dt className="text-ink-muted">σ</dt>
                                <dd className="text-right font-mono tabular-nums">
                                    {row.result.sigma.toFixed(1)}
                                </dd>
                                <dt className="text-ink-muted">cp_value</dt>
                                <dd className="text-right font-mono tabular-nums">
                                    {row.result.cp_value}
                                </dd>
                                <dt className="text-ink-muted">유효 타일</dt>
                                <dd className="text-right font-mono tabular-nums">
                                    {row.result.n_valid}
                                </dd>
                            </dl>

                            {row.result.medgemma_report && (
                                <div className="text-sm">
                                    <div className="mb-1 text-ink-muted">판독 요약</div>
                                    {row.result.medgemma_report.generation_failed ? (
                                        <p className="text-ink-faint">
                                            리포트 생성에 실패했습니다.
                                        </p>
                                    ) : (
                                        <p className="leading-relaxed">
                                            {row.result.medgemma_report.summary}
                                        </p>
                                    )}
                                </div>
                            )}

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
