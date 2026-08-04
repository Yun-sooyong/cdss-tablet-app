import { Link, useSearchParams } from 'react-router-dom';

import { getImage, getJobs } from '@/api';
import type { Job, JobResult } from '@/api/types';
import { DecisionBadge, JobStatusBadge } from '@/components/StatusBadge';
import { IntervalBar } from '@/components/IntervalBar';
import { Card, CardContent } from '@/components/ui/card';
import {
    Sheet,
    SheetContent,
    SheetHeader,
    SheetTitle,
} from '@/components/ui/sheet';
import type { IntervalView } from '@/lib/decision';
import { CUTOFF, needsReview, toIntervalView } from '@/lib/decision';

const GRID =
    'grid grid-cols-[minmax(6rem,13rem)_minmax(0,1fr)_4.5rem_3.5rem_6.5rem] items-center gap-x-4';

const AXIS_TICKS = [0, 25, 50, 75, 100];

interface Row {
    job : Job;
    result : JobResult;
    view : IntervalView;
    filename : string;
}

// 결과가 나온 것만
function buildRows() : Row[] {
    return getJobs()
        .filter((j) => j.status === 'succeeded' || j.status === 'stil_done')
        .flatMap((job) => {
            if (!job.result) return [];
            return [{
                job,
                result: job.result,
                view: toIntervalView(job.result),
                filename: getImage(job.image)?.original_filename ?? job.id.slice(0, 8),
            }];
        })
        // ABSTAIN 먼저
        .sort((a, b) => {
            const aRank = needsReview(a.result) ? 0 : 1;
            const bRank = needsReview(b.result) ? 0 : 1;
            if (aRank !== bRank) return aRank - bRank;
            return b.view.width - a.view.width;
        });
}

export default function AbstainReviewPage() {
    const [searchParams, setSearchParams] = useSearchParams();

    const rows = buildRows();
    const reviewCount = rows.filter((r) => needsReview(r.result)).length;

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
                <h1 className="text-lg font-semibold">판정 유보 검증함</h1>
                <div className="text-sm text-ink-muted">
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
                <CardLayout rows={rows} onSelect={select} />
            ) : (
                <AxisLayout rows={rows} onSelect={select} />
            )}

            <DetailSheet row={selected} onClose={() => select(null)} />
        </div>
    );
}


// 공유 축 >> 컷오프 선 하나가 목록 전체를 세로로 관통한다.
function AxisLayout({
    rows,
    onSelect,
} : {
    rows : Row[];
    onSelect : (id : string) => void;
}) {
    return (
        <div>
            {/* 눈금 */}
            <div className={`${GRID} mb-1 text-[11px] text-ink-faint`}>
                <div />
                <div className="relative h-4">
                    {AXIS_TICKS.map((t) => (
                        <span
                            key={t}
                            className="absolute -translate-x-1/2"
                            style={{ left: `${t}%` }}
                        >
                            {t}
                        </span>
                    ))}
                </div>
                <div className="text-right">sTIL</div>
                <div className="text-right">σ</div>
                <div />
            </div>

            <div className="relative">
                {/* 컷오프 오버레이 >> 행이 아니라 목록 전체에 한 번만 그린다 */}
                <div className={`${GRID} pointer-events-none absolute inset-0`}>
                    <div />
                    <div className="relative h-full">
                        <div
                            className="absolute inset-y-0 w-px bg-border-strong"
                            style={{ left: `${CUTOFF}%` }}
                        />
                    </div>
                </div>

                <div className="divide-y divide-border">
                    {rows.map((row) => (
                        <button
                            key={row.job.id}
                            type="button"
                            onClick={() => onSelect(row.job.id)}
                            className={`${GRID} w-full py-3 text-left transition-colors hover:bg-brand-soft/50`}
                        >
                            <span className="truncate text-sm" title={row.filename}>
                                {row.filename}
                            </span>

                            <IntervalBar view={row.view} />

                            <span className="text-right font-mono text-sm tabular-nums">
                                {row.result.stil_value.toFixed(1)}
                            </span>
                            <span className="text-right font-mono text-xs tabular-nums text-ink-muted">
                                {row.result.sigma.toFixed(1)}
                            </span>

                            <span className="flex justify-end">
                                <DecisionBadge decision={row.result.decision} />
                            </span>
                        </button>
                    ))}
                </div>
            </div>

            <div className="mt-2 text-right text-[11px] text-ink-faint">
                세로선 = 임상 컷오프 {CUTOFF}%
            </div>
        </div>
    );
}

// 3건 이하 >> 카드로 전환
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
                <Card
                    key={row.job.id}
                    onClick={() => onSelect(row.job.id)}
                    className="cursor-pointer transition-colors hover:border-border-strong"
                >
                    <CardContent className="space-y-4">
                        <div className="flex items-start justify-between gap-2">
                            <span className="truncate text-sm" title={row.filename}>
                                {row.filename}
                            </span>
                            <DecisionBadge decision={row.result.decision} />
                        </div>

                        <div className="font-mono text-3xl tabular-nums">
                            {row.result.stil_value.toFixed(1)}
                            <span className="ml-1 text-base text-ink-muted">%</span>
                        </div>

                        <IntervalBar view={row.view} showCutoff />

                        <div className="flex justify-between text-xs text-ink-muted">
                            <span className="font-mono tabular-nums">
                                {row.result.lower.toFixed(1)} ~ {row.result.upper.toFixed(1)}
                            </span>
                            <span className="font-mono tabular-nums">σ {row.result.sigma.toFixed(1)}</span>
                        </div>
                    </CardContent>
                </Card>
            ))}
        </div>
    );
}


// 상세 시트
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
                            <SheetTitle className="truncate text-base">
                                {row.filename}
                            </SheetTitle>
                        </SheetHeader>

                        <div className="space-y-6 px-4 pb-6">
                            <div className="flex gap-2">
                                <DecisionBadge decision={row.result.decision} />
                                <JobStatusBadge status={row.job.status} />
                            </div>

                            <div>
                                <div className="font-mono text-4xl tabular-nums">
                                    {row.result.stil_value.toFixed(1)}
                                    <span className="ml-1 text-lg text-ink-muted">%</span>
                                </div>
                                <div className="mt-3">
                                    <IntervalBar view={row.view} showCutoff />
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
                                        <p className="text-ink-faint">리포트 생성에 실패했습니다.</p>
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
