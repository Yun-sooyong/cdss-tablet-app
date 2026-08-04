import type { ReactNode } from 'react';
import { Minus, Plus } from 'lucide-react';

import { cn } from '@/lib/utils';

// 행과 오버레이가 같은 컬럼 템플릿을 써야 컷오프 선이 축 컬럼에 정확히 얹힌다.
export const AXIS_GRID =
    'grid grid-cols-[minmax(7rem,15rem)_minmax(0,1fr)_5rem_4rem_7rem] items-center gap-x-5';

const clamp = (n : number) : number => Math.min(100, Math.max(0, n));

export function IntervalAxis({
    cutoff,
    onCutoffChange,
    gridClassName = AXIS_GRID,
    axisColStart = 2,
    leading,
    trailing,
    children,
} : {
    cutoff : number;
    onCutoffChange? : (value : number) => void;
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
        <div>
            {onCutoffChange && (
                <div className={cn(gridClassName, 'mb-4')}>
                    {leadingCells}
                    <div className="flex items-center gap-4">
                        <span className="shrink-0 text-sm text-ink-muted">컷오프</span>

                        <input
                            type="range"
                            min={0}
                            max={100}
                            value={cutoff}
                            onChange={(e) => onCutoffChange(Number(e.target.value))}
                            aria-label="컷오프 값"
                            className="h-2 flex-1 cursor-pointer accent-[var(--decision-abstain)]"
                        />

                        <div className="flex h-9 shrink-0 items-stretch overflow-hidden rounded-md border border-border bg-surface">
                            <StepButton
                                label="컷오프 1 낮추기"
                                onClick={() => onCutoffChange(clamp(cutoff - 1))}
                            >
                                <Minus size={15} />
                            </StepButton>

                            <input
                                type="number"
                                min={0}
                                max={100}
                                value={cutoff}
                                onChange={(e) => {
                                    const v = Number(e.target.value);
                                    if (!Number.isNaN(v)) onCutoffChange(clamp(v));
                                }}
                                aria-label="컷오프 값 직접 입력"
                                className="w-14 border-x border-border bg-transparent text-center font-mono text-base tabular-nums text-ink focus:outline-none [appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none"
                            />

                            <StepButton
                                label="컷오프 1 높이기"
                                onClick={() => onCutoffChange(clamp(cutoff + 1))}
                            >
                                <Plus size={15} />
                            </StepButton>
                        </div>

                        <span className="shrink-0 text-sm text-ink-muted">%</span>
                    </div>
                </div>
            )}

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

function StepButton({
    label,
    onClick,
    children,
} : {
    label : string;
    onClick : () => void;
    children : ReactNode;
}) {
    return (
        <button
            type="button"
            onClick={onClick}
            aria-label={label}
            className="flex w-9 items-center justify-center text-ink-muted transition-colors hover:bg-brand-soft hover:text-ink"
        >
            {children}
        </button>
    );
}
