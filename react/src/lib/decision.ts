import type { Decision, Job, JobResult } from '@/api/types';

/* Cutoff */
export const CUTOFF = 50;


/* Decision Labels */
export const DECISION_LABEL : Record<Decision, string> = {
    LOW : '낮음',
    HIGH : '높음',
    ABSTAIN : '확인 필요',
};


/* Review */

export const needsReview = (job : Pick<Job, 'result' | 'review'>) : boolean =>
    job.result?.decision === 'ABSTAIN' && !job.review;

// finalDecision 
export const finalDecision = (job : Pick<Job, 'result' | 'review'>) : Decision | null =>
    job.review?.decision ?? job.result?.decision ?? null;

/* Interval */
export interface IntervalView {
    value : number;
    lower : number;
    upper : number;
    cutoff : number;
    left : number;
    width : number;
    // 구간이 축을 벗어났나
    clippedLow : boolean;
    clippedHigh : boolean;
    // crossesCutoff >> 표시 전용. 분류에 쓰지 말 것.
    crossesCutoff : boolean;
}

const clamp = (n : number) : number => Math.min(100, Math.max(0, n));

// toIntervalView >> 클리핑을 여기서 흡수
export const toIntervalView = (result : JobResult) : IntervalView => {
    const cutoff = result.cutoff ?? CUTOFF;
    const left = clamp(result.lower);
    const right = clamp(result.upper);

    return {
        value : result.stil_value,
        lower : result.lower,
        upper : result.upper,
        cutoff,
        left,
        width : right - left,
        clippedLow : result.lower < 0,
        clippedHigh : result.upper > 100,
        crossesCutoff : result.lower <= cutoff && cutoff <= result.upper,
    };
};
