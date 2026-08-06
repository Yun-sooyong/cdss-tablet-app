export type JobStatus = 'queued' | 'running' | 'stil_done' | 'succeeded' | 'failed';
export type BatchStatus = 'pending' | 'processing' | 'done' | 'failed';
export type Decision = 'LOW' | 'HIGH' | 'ABSTAIN';
export type Sex = 'M' | 'F' | 'O' | 'U';

// PatientSummary
export interface PatientSummary {
    id : string;
    chart_number : string;
    name : string;
    birth_date : string;
    sex : Sex;
}

// PatientCreate
export interface PatientCreate {
    name : string;
    birth_date : string;
    sex : Sex;
    phone : string;
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

// Paginated >> 최대 200자 (서버)
export interface Paginated<T> {
    count : number;
    limit : number;
    offset : number;
    results : T[];
}

export interface BatchQuery {
    status? : BatchStatus;
    q? : string;
    patient? : string;
    // shared >> 공유 받은거만 필터링
    shared? : boolean;
    date_from? : string;
    date_to? : string;
    limit? : number;
    offset? : number;
}

export interface Batch {
    id : string;
    patient : string | null;
    patient_summary : PatientSummary | null;
    status : BatchStatus;
    image_count : number;
    needs_review_count : number;
    created_by : string;
    created_at : string;
    updated_at : string;
}

// ImageSummary
export interface ImageSummary {
    id : string;
    original_filename : string;
}

// BatchDetail
export interface BatchDetail extends Batch {
    jobs : Job[];
}

export interface ImageUpload {
    id : string;
    batch : string;
    storage_key : string;
    original_filename : string;
    created_at : string;
    upload_url : string;
    upload_content_type : string;
}

export type ReviewDecision = Exclude<Decision, 'ABSTAIN'>;

// 확정해도 Job.result는 워커 것이라 그대로 남는다
export interface JobReview {
    id : string;
    decision : ReviewDecision;
    reason : string;
    reviewed_by : string;
    created_at : string;
}

export interface JobReviewCreate {
    decision : ReviewDecision;
    reason : string;
}

export interface Job {
    id : string;
    image : string;
    image_summary : ImageSummary | null;
    original_url : string;
    model_version : string;
    status : JobStatus;
    result : JobResult | null;
    // 번복하면 최신 1건만 온다
    review : JobReview | null;
    mask_url : string | null;
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


/* 의료진 계정 >> /api/v1/staff */

export type Role = 'doctor' | 'nurse' | 'admin';
export type EmploymentStatus = 'active' | 'leave' | 'resigned';

export interface Staff {
    id : string;
    username : string;
    email : string;
    role : Role;
    department : string;
    employment_status : EmploymentStatus;
    resigned_at : string | null;
    created_at : string;
}

// StaffMeUpdate 
export interface StaffMeUpdate {
    department? : string;
}

// PasswordChange 
export interface PasswordChange {
    old_password : string;
    new_password : string;
}

export interface Department {
    dept_code : string;
    name : string;
    extension : string;
}


/* 계정 요청 >> /api/v1/auth/account-requests */

export type AccountRequestStatus = 'pending' | 'approved' | 'rejected';

export interface AccountRequest {
    id : string;
    name : string;
    email : string;
    role : Role;
    department : string;
    note : string;
    status : AccountRequestStatus;
    created_at : string;
    reviewed_at : string | null;
    reviewed_by : string | null;
}

export interface AccountRequestCreate {
    name : string;
    email : string;
    role : Role;
    department? : string;
    note? : string;
}

export interface AccountRequestApprove {
    username : string;
    role : Role;
    department? : string;
}

// AccountRequestApproved 
export interface AccountRequestApproved {
    username : string;
    temporary_password : string;
}


/* 알림 >> /api/v1/notifications */

export type NotificationType = 'analysis_done' | 'share' | 'chat' | 'account_request';

// AppNotification 
export interface AppNotification {
    id : string;
    type : NotificationType;
    body : string;
    target_type : string;
    target_id : string | null;
    is_read : boolean;
    created_at : string;
}


/* 공유 >> /api/v1/analysis/batches/{id}/shares · /api/v1/analysis/shares/{id} */

export interface AnalysisShare {
    id : string;
    batch : string;
    shared_by : string;
    shared_to : string;
    // 서버가 200자로 자른다
    opinion : string;
    expires_at : string | null;
    // revoked_at >> 회수는 물리 삭제 X
    revoked_at : string | null;
    created_at : string;
}

export interface AnalysisShareCreate {
    shared_to : string;
    opinion? : string;
    expires_at? : string | null;
}
