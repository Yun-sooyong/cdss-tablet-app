import type { BatchStatus, JobStatus } from "@/api/types";

/* Job Status Utilities */
export const isBatchTerminal = (status : BatchStatus) : boolean =>
    status === 'done' || status === 'failed';


/* Job Status Labels */
export const JOB_STATUS_LABEL : Record<JobStatus, string> = {
    queued : '대기',
    running : '분석 중',
    // stil_done >> sTIL 값은 나왔고 리포트가 남은 상태
    stil_done : '1차 완료',
    succeeded : '완료',
    failed : '실패',
};


/* Batch Status Labels */
export const BATCH_STATUS_LABEL : Record<BatchStatus, string> = {
    pending : '대기',
    processing : '분석 중',
    done : '완료',
    failed : '실패',
};

