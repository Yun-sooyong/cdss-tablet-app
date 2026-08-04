import type { ReactNode } from 'react';

import { cn } from '@/lib/utils';

// 행과 오버레이가 같은 컬럼 템플릿을 써야 컷오프 선이 축 컬럼에 정확히 얹힌다.
// min-w >> 좁아져도 막대 컬럼이 0으로 찌그러지지 않게. 대신 가로 스크롤된다
export const AXIS_GRID =
    'grid min-w-[46rem] grid-cols-[minmax(7rem,15rem)_minmax(0,1fr)_5rem_4rem_7rem] items-center gap-x-5';

export function IntervalAxis({
    cutoff,
    gridClassName = AXIS_GRID,
    axisColStart = 2,
    leading,
    trailing,
    children,
} : {
    cutoff : number;
    gridClassName? : string;
    axisColStart? : number;
    // leading trailing >> 축 컬럼 앞뒤에 오는 컬럼 헤더.
    // 행과 같은 템플릿을 쓰므로 정렬이 맞는다
    leading? : ReactNode;
    trailing? : ReactNode;
    children : ReactNode;
}) {
    const leadingCells = Array.from({ length: axisColStart - 1 }, (_, i) => <div key={i} />);

    return (
        <div className="overflow-x-auto">
            <div
                className={cn(
                    gridClassName,
                    'mb-1.5 border-b border-border pb-1.5 text-xs text-ink-muted',
                )}
            >
                {leading ?? leadingCells}
                <div className="relative h-4">
                    <span className="absolute left-0 tabular-nums">0</span>
                    <span className="absolute left-1/2 -translate-x-1/2 tabular-nums">50</span>
                    <span className="absolute right-0 tabular-nums">100</span>
                </div>
                {trailing}
            </div>

            <div className="relative">
                <div className={cn(gridClassName, 'pointer-events-none absolute inset-0')}>
                    {leadingCells}
                    <div className="relative h-full">
                        <div
                            className="absolute inset-y-0 w-0.5 -translate-x-1/2 bg-decision-abstain/70"
                            style={{ left: `${cutoff}%` }}
                        />
                    </div>
                </div>

                {children}
            </div>
        </div>
    );
}
