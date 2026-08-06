import { ArrowRight, CircleAlert } from 'lucide-react';

import type {Decision, JobReview, JobStatus, BatchStatus} from '@/api/types';
import {Badge} from '@/components/ui/badge';
import {DECISION_LABEL} from '@/lib/decision'
import {BATCH_STATUS_LABEL, JOB_STATUS_LABEL} from '@/lib/jobStatus'
import {cn} from '@/lib/utils';

const DECISION_STYLE : Record<Decision, string> = {
    LOW: 'border-decision-low/50 bg-decision-low/12 text-decision-low',
    HIGH: 'border-decision-high/50 bg-decision-high/12 text-decision-high',
    ABSTAIN: 'border-decision-abstain/60 bg-decision-abstain/18 text-decision-abstain',
};

// DecisionBadge >> Label 
export function DecisionBadge({
    decision,
    className,
} : {
    decision : Decision;
    className? : string;
}) {
    return (
        <Badge
            variant="outline"
            className={cn(
                'h-auto px-2.5 py-1 text-sm font-medium',
                DECISION_STYLE[decision],
                className,
            )}
        >
            {decision === 'ABSTAIN' && <CircleAlert />}
            {DECISION_LABEL[decision]}
        </Badge>
    );
}

export function ConfirmedDecision({
    decision,
    review,
    className,
} : {
    decision : Decision;
    review : JobReview;
    className? : string;
}) {
    return (
        <span className={cn('flex flex-wrap items-center gap-1.5', className)}>
            <Badge
                variant="outline"
                className="h-auto border-border px-2 py-0.5 text-sm text-ink-faint line-through decoration-ink-faint/60"
            >
                {DECISION_LABEL[decision]}
            </Badge>

            <ArrowRight size={13} className="shrink-0 text-ink-faint" />

            <Badge
                variant="outline"
                className={cn(
                    'h-auto px-2.5 py-1 text-sm font-medium',
                    DECISION_STYLE[review.decision],
                )}
            >
                {DECISION_LABEL[review.decision]} · 확정
            </Badge>
        </span>
    );
}

// Label로 구분
const JOB_STATUS_STYLE : Record<JobStatus, string> = {
    queued: 'border-border text-ink-faint',
    running: 'border-border text-ink-muted',
    stil_done: 'border-border text-ink-muted',
    succeeded: 'border-border text-ink-muted',
    failed: 'border-danger/40 bg-danger/10 text-danger',
};

// JobStatusBadge >> Label
export function JobStatusBadge({
    status,
    className,
} : {
    status : JobStatus;
    className? : string;
}) {
    return (
        <Badge variant="outline" className={cn(JOB_STATUS_STYLE[status], className)}>
            {JOB_STATUS_LABEL[status]}
        </Badge>
    );
}

// Batch는 Job과 종료값 이름이 달라 배지를 따로 둔다
const BATCH_STATUS_STYLE : Record<BatchStatus, string> = {
    pending: 'border-border text-ink-faint',
    processing: 'border-border text-ink-muted',
    done: 'border-border text-ink-muted',
    failed: 'border-danger/50 bg-danger/12 text-danger',
};

export function BatchStatusBadge({ status } : { status : BatchStatus }) {
    return (
        <Badge
            variant="outline"
            className={cn('px-2.5 py-1 text-sm font-medium', BATCH_STATUS_STYLE[status])}
        >
            {BATCH_STATUS_LABEL[status]}
        </Badge>
    );
}
