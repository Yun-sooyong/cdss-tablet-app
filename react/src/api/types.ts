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

// BatchDetail >> GET /analysis/batches/{id}/ 응답. job 목록이 딸려 온다
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

// StaffMeUpdate >> role은 권한 상승 위험이라 서버가 막는다
export interface StaffMeUpdate {
    department? : string;
}

// PasswordChange >> 환자·의료진 공용. 새 비밀번호 8자 이상
export interface PasswordChange {
    old_password : string;
    new_password : string;
}

export interface Department {
    dept_code : string;
    name : string;
    extension : string;
}


/* 초대코드 >> /api/v1/staff/invitations · /api/v1/auth/invitations/redeem */

export interface Invitation {
    code : string;
    role : Role;
    department : string;
    expires_at : string;
    is_used : boolean;
    created_at : string;
}

export interface InvitationIssue {
    role : Role;
    department? : string;
    expires_in_days? : number;
}

export interface InvitationRedeem {
    code : string;
    username : string;
    email : string;
    password : string;
}


/* 알림 >> /api/v1/notifications */

export type NotificationType = 'analysis_done' | 'share' | 'chat';

// AppNotification >> DOM 전역 Notification과 겹쳐서 접두사를 붙임
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

export type SharePermission = 'read' | 'comment';

export interface AnalysisShare {
    id : string;
    batch : string;
    shared_by : string;
    shared_to : string;
    permission : SharePermission;
    expires_at : string | null;
    // revoked_at >> 회수는 물리 삭제가 아니라 이 값이 찍히는 것
    revoked_at : string | null;
    created_at : string;
}

export interface AnalysisShareCreate {
    shared_to : string;
    permission? : SharePermission;
    expires_at? : string | null;
}
