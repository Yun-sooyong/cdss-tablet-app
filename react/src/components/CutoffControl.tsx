import { Minus, Plus } from 'lucide-react';

import { ICON_BUTTON } from '@/components/form';

const clamp = (n : number) : number => Math.min(100, Math.max(0, n));

/* 컷오프 조작 >> 09 판정 유보 검증함. 표와 카드 어느 쪽이든 위에 붙는다 */
export function CutoffControl({
    cutoff,
    onChange,
} : {
    cutoff : number;
    onChange : (value : number) => void;
}) {
    return (
        <div className="mb-4 flex flex-wrap items-center gap-x-4 gap-y-2">
            <span className="shrink-0 text-sm text-ink-muted">컷오프</span>

            <input
                type="range"
                min={0}
                max={100}
                value={cutoff}
                onChange={(e) => onChange(Number(e.target.value))}
                aria-label="컷오프 값"
                className="h-2 min-w-40 flex-1 cursor-pointer accent-[var(--decision-abstain)]"
            />

            <div className="flex h-9 shrink-0 items-stretch overflow-hidden rounded-md border border-border bg-surface">
                <StepButton label="컷오프 1 낮추기" onClick={() => onChange(clamp(cutoff - 1))}>
                    <Minus size={15} />
                </StepButton>

                <input
                    type="number"
                    min={0}
                    max={100}
                    value={cutoff}
                    onChange={(e) => {
                        const v = Number(e.target.value);
                        if (!Number.isNaN(v)) onChange(clamp(v));
                    }}
                    aria-label="컷오프 값 직접 입력"
                    className="w-14 border-x border-border bg-transparent text-center font-mono text-base tabular-nums text-ink focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-brand [appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none"
                />

                <StepButton label="컷오프 1 높이기" onClick={() => onChange(clamp(cutoff + 1))}>
                    <Plus size={15} />
                </StepButton>
            </div>

            <span className="shrink-0 text-sm text-ink-muted">%</span>
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
    children : React.ReactNode;
}) {
    return (
        <button
            type="button"
            onClick={onClick}
            aria-label={label}
            className={`flex w-9 items-center justify-center hover:bg-brand-soft ${ICON_BUTTON}`}
        >
            {children}
        </button>
    );
}
