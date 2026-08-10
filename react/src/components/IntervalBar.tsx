// 좌표계산 X


import type { Decision } from '@/api/types';
import type { IntervalView } from '@/lib/decision';
import { cn } from '@/lib/utils';

const BAR_STYLE : Record<Decision, string> = {
    LOW: 'bg-decision-low/55',
    HIGH: 'bg-decision-high/55',
    ABSTAIN: 'bg-decision-abstain/60',
};

const MARKER_STYLE : Record<Decision, string> = {
    LOW: 'bg-decision-low',
    HIGH: 'bg-decision-high',
    ABSTAIN: 'bg-decision-abstain',
};

export function IntervalBar({
    view,
    decision,
    className,
} : {
    view : IntervalView;
    decision : Decision;
    className? : string;
}) {
    return (
        <div className={cn('relative h-9 w-full', className)}>

            <div /* IntervalBar 배경 */
            className="absolute inset-x-0 top-1/2 h-px -translate-y-1/2 bg-border" />

            <div /* IntervalBar */
                className={cn(
                    'absolute top-1/2 h-3.5 -translate-y-1/2 rounded-full',
                    BAR_STYLE[decision],
                    view.clippedLow && 'rounded-l-none',
                    view.clippedHigh && 'rounded-r-none',
                )}
                style={{ left: `${view.left}%`, width: `${view.width}%` }}
            />


            <div /* IntervalBar 값 마커 */
                className={cn(
                    'absolute top-1/2 h-6 w-[3px] -translate-x-1/2 -translate-y-1/2 rounded-full',
                    MARKER_STYLE[decision],
                )}
                style={{ left: `${view.value}%` }}
            />
        </div>
    );
}
