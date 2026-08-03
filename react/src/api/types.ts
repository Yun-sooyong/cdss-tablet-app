export type JobStatus = 'queued' | 'running' | 'stil_done' | 'succeeded' | 'failed';
export type BatchStatus = 'pending' | 'processing' | 'done' | 'failed';
export type Decision = 'LOW' | 'HIGH' | 'ABSTAIN';

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
