import type { ReactNode } from 'react';

import { cn } from '@/lib/utils';

// ListFrame
export function ListFrame({
    grid,
    header,
    children,
} : {
    grid : string;
    header : ReactNode;
    children : ReactNode;
}) {
    return (
        <div className="overflow-x-auto" tabIndex={0}>
            <div
                className={cn(grid, 'mb-1.5 border-b border-border pb-1.5 text-xs text-ink-muted')}
            >
                {header}
            </div>

            {children}
        </div>
    );
}
