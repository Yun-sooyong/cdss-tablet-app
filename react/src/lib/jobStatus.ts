import type { BatchStatus, JobStatus } from "@/api/types";

/* Job Status Utilities */
export const isTerminal = (status : JobStatus) : boolean =>
    status === 'succeeded' || status === 'failed';

export const isBatchTerminal = (status : BatchStatus) : boolean =>
    status === 'done' || status === 'failed';


/* Job Status Labels */
export const JOB_STATUS_LABEL : Record<JobStatus, string> = {
    queued : '대기 중..',
    running : '실행 중..',
    stil_done : 'sTIL 분석완료',
    succeeded : '완료',
    failed : '실패',
};


/* Batch Status Labels */
export const BATCH_STATUS_LABEL : Record<BatchStatus, string> = {
    pending : '대기 중..',
    processing : '처리 중..',
    done : '완료',
    failed : '실패',
};

