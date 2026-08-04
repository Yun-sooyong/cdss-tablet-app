import { Info } from 'lucide-react';

import { CLINICAL_NOTICE } from '@/lib/notice';
import { cn } from '@/lib/utils';

/* 임상 고지 >> 08 결과 상세 · 09 판정 유보 검증함 */
export function ClinicalNotice({ className } : { className? : string }) {
    return (
        <p
            className={cn(
                'flex items-start gap-1.5 text-xs text-ink-faint',
                className,
            )}
        >
            <Info size={13} className="mt-px shrink-0" />
            {CLINICAL_NOTICE}
        </p>
    );
}
