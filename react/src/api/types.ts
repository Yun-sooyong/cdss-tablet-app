export type JobStatus = 'queued' | 'running' | 'stil_done' | 'succeeded' | 'failed';
export type BatchStatus = 'pending' | 'processing' | 'done' | 'failed';
export type Decision = 'LOW' | 'HIGH' | 'ABSTAIN';
export type Sex = 'M' | 'F' | 'O' | 'U';

// PatientSummary >> batch/job 응답에 끼워 넣는 판독 맥락용 최소 정보.
// 주소 전화번호처럼 민감한 필드는 들어오지 않는다.
export interface PatientSummary {
    id : string;
    chart_number : string;
    name : string;
    birth_date : string;
    sex : Sex;
}

export type ClassComposition = {
    tumor : number; stroma : number; immune : number;
    necrosis : number; other : number;
};

export type MedgemmaReport = {
    summary : string;
    generation_failed : boolean;
};

export interface JobResult {
    stil_value : number;
    sigma : number;
    lower : number;
    upper : number;
    abstain : boolean;
    decision : Decision;
    cp_value : number;
    n_valid : number;
    cutoff? : number;
    class_composition : ClassComposition;
    medgemma_report? : MedgemmaReport;
}

export interface Batch {
    id : string;
    patient : string | null;
    patient_summary : PatientSummary | null;
    status : BatchStatus;
    created_by : string;
    created_at : string;
    updated_at : string;
}

export interface ImageUpload {
    id : string;
    batch : string;
    storage_key : string;
    original_filename : string;
    created_at : string;
    upload_url : string;
}

export interface Job {
    id : string;
    image : string;
    model_version : string;
    status : JobStatus;
    result : JobResult | null;
    patient_summary : PatientSummary | null;
    error_message : string;
    started_at : string | null;
    finished_at : string | null;
    created_at : string;
}

export interface ModelVersion {
    id : string;
    name : string;
    version : string;
    conformal_q : number;
    is_active : boolean;
    created_at : string;
}

export interface TokenPair {
    access : string;
    refresh : string;
}
