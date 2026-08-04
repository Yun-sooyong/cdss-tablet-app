// 09 판정 유보 검증함
import { Link, useSearchParams } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';

import { getImages, getLatestJobs } from '@/api';
import { qk } from '@/api/keys';
import type { Job, JobResult } from '@/api/types';
import { AXIS_GRID, IntervalAxis } from '@/components/IntervalAxis';
import { ClinicalNotice } from '@/components/ClinicalNotice';
import { CutoffControl } from '@/components/CutoffControl';
import { IntervalBar } from '@/components/IntervalBar';
import { Failed, Pending } from '@/components/QueryState';
import { DecisionBadge } from '@/components/StatusBadge';
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

// 결과가 나온 job만, σ 내림차순
function buildRows(
    jobs : Job[],
    filenameOf : (imageId : string) => string | undefined,
    cutoff : number,
) : Row[] {
    return jobs
        .filter((j) => j.status === 'succeeded' || j.status === 'stil_done')
        .flatMap((job) => {
            if (!job.result) return [];
            return [{
                job,
                result: job.result,
                view: toIntervalView(job.result, cutoff),
                filename: filenameOf(job.image) ?? job.id.slice(0, 8),
            }];
        })
        .sort((a, b) => b.result.sigma - a.result.sigma);
}

const clampCutoff = (n : number) : number => Math.min(100, Math.max(0, n));

export default function AbstainReviewPage() {
    const [searchParams, setSearchParams] = useSearchParams();

    // cutoff >> URL 파라미터
    const raw = Number(searchParams.get('cutoff'));
    const cutoff = Number.isFinite(raw) && searchParams.has('cutoff')
        ? clampCutoff(raw)
        : CUTOFF;

    function setCutoff(next : number) {
        const params = new URLSearchParams(searchParams);
        if (clampCutoff(next) === CUTOFF) params.delete('cutoff');
        else params.set('cutoff', String(clampCutoff(next)));

        setSearchParams(params, { replace: true });
    }

    const jobs = useQuery({ queryKey: qk.latestJobs, queryFn: getLatestJobs });

    // filename >> job에는 image UUID만 있어 따로 짝지운다
    const { data: images } = useQuery({ queryKey: qk.images, queryFn: getImages });
    const filenameOf = (imageId : string) =>
        images?.find((i) => i.id === imageId)?.original_filename;

    const selectedId = searchParams.get('job');

    function select(id : string | null) {
        const next = new URLSearchParams(searchParams);
        if (id) next.set('job', id);
        else next.delete('job');
        setSearchParams(next, { replace: true });
    }

    if (jobs.isPending) return <Pending />;
    if (jobs.isError) return <Failed error={jobs.error} onRetry={() => void jobs.refetch()} />;

    const rows = buildRows(jobs.data, filenameOf, cutoff);
    const reviewCount = rows.filter((r) => r.view.crossesCutoff).length;
    const selected = rows.find((r) => r.job.id === selectedId) ?? null;

    return (
        <div>
            <div className="mb-2 text-[15px] text-ink-muted">
                결과 {rows.length}건 중{' '}
                <span className="font-semibold text-decision-abstain">
                    확인 필요 {reviewCount}건
                </span>
            </div>

            <ClinicalNotice className="mb-6" />

            {/* 컷오프는 표든 카드든 항상 조작할 수 있어야 한다 */}
            {rows.length > 0 && <CutoffControl cutoff={cutoff} onChange={setCutoff} />}

            {rows.length === 0 ? (
                <div className="py-16 text-center text-sm text-ink-faint">
                    판독 결과가 없습니다
                </div>
            ) : rows.length <= 3 ? (
                <CardLayout rows={rows} cutoff={cutoff} onSelect={select} />
            ) : (
                <IntervalAxis
                    cutoff={cutoff}
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

function SlideRows({
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

                        {/* 값 · 구간 · 판정. 나머지는 08 결과 상세 */}
                        <div className="space-y-6 px-4 pb-6">
                            <DecisionBadge decision={classifyAt(row.result, cutoff)} />

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
                                <div className="mt-2 flex justify-between font-mono text-xs tabular-nums text-ink-muted">
                                    <span>{row.result.lower.toFixed(1)}</span>
                                    <span>예측 구간 · σ {row.result.sigma.toFixed(1)}</span>
                                    <span>{row.result.upper.toFixed(1)}</span>
                                </div>
                            </div>

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
