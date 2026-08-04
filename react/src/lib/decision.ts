import type { Decision, JobResult } from '@/api/types';

/* Cutoff */
export const CUTOFF = 50;


/* Decision Labels */
export const DECISION_LABEL : Record<Decision, string> = {
    LOW : '낮음',
    HIGH : '높음',
    ABSTAIN : '확인 필요',
};


/* Review */
export const needsReview = (result : JobResult | null) : boolean =>
    result?.decision === 'ABSTAIN';

// classifyAt >> 컷오프를 옮겼을 때의 분류를 클라이언트에서 계산한다.
// 백엔드 decision은 서버 컷오프 기준이라 슬라이더를 움직이면 더 이상 맞지 않는다.
export const classifyAt = (result : JobResult, cutoff : number) : Decision => {
    if (result.lower <= cutoff && cutoff <= result.upper) return 'ABSTAIN';
    return result.stil_value < cutoff ? 'LOW' : 'HIGH';
};


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
export const toIntervalView = (
    result : JobResult,
    cutoffOverride? : number,
) : IntervalView => {
    const cutoff = cutoffOverride ?? result.cutoff ?? CUTOFF;
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
