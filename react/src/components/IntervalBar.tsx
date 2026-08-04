// 좌표계산 X

import type { IntervalView } from '@/lib/decision';
import { cn } from '@/lib/utils';


export function IntervalBar({
    view,
    showCutoff = false,
    className,
} : {
    view : IntervalView;
    showCutoff? : boolean;
    className? : string;
}) {
    return (
        <div className={cn('relative h-6 w-full', className)}>

            <div /* IntervalBar 배경 */ 
            className="absolute inset-x-0 top-1/2 h-px -translate-y-1/2 bg-border" />

            {showCutoff && (
                <div
                    className="absolute inset-y-0 w-px bg-border-strong"
                    style={{ left: `${view.cutoff}%` }}
                />
            )}

            <div /* IntervalBar */
                className={cn(
                    'absolute top-1/2 h-2 -translate-y-1/2 rounded-full',
                    view.crossesCutoff ? 'bg-decision-abstain/30' : 'bg-ink-faint/25',
                    view.clippedLow && 'rounded-l-none',
                    view.clippedHigh && 'rounded-r-none',
                )}
                style={{ left: `${view.left}%`, width: `${view.width}%` }}
            />


            <div /* IntervalBar 값 마커 */
                className={cn(
                    'absolute top-1/2 h-3.5 w-0.5 -translate-x-1/2 -translate-y-1/2',
                    view.crossesCutoff ? 'bg-decision-abstain' : 'bg-ink-muted',
                )}
                style={{ left: `${view.value}%` }}
            />
        </div>
    );
}
