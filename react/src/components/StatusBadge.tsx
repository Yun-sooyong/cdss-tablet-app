import type {Decision, JobStatus} from '@/api/types';
import {Badge} from '@/components/ui/badge';
import {DECISION_LABEL} from '@/lib/decision'
import {JOB_STATUS_LABEL} from '@/lib/jobStatus'
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
                'px-2.5 py-1 text-sm font-medium',
                DECISION_STYLE[decision],
                className,
            )}
        >
            {DECISION_LABEL[decision]}
        </Badge>
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
