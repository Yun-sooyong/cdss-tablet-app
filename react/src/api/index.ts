import type {
    AccountRequest,
    AccountRequestApprove,
    AccountRequestApproved,
    AccountRequestCreate,
    AccountRequestStatus,
    AnalysisShare,
    AnalysisShareCreate,
    AppNotification,
    Batch,
    BatchDetail,
    BatchQuery,
    Department,
    Disease,
    Drug,
    Paginated,
    Prescription,
    PrescriptionCreate,
    Visit,
    VisitCreate,
    ImageUpload,
    Job,
    JobReview,
    JobReviewCreate,
    ModelVersion,
    PasswordChange,
    PatientCreate,
    PatientSummary,
    Role,
    Staff,
    StaffMeUpdate,
    TokenPair,
} from '@/api/types';
import {
    ApiError,
    del,
    get,
    getSession,
    patch,
    post,
    putFile,
    query,
    setSession,
} from '@/api/http';

// latestPerImage >> image당 최신 job 하나
export const latestPerImage = (list : Job[]) : Job[] => {
    const latest = new Map<string, Job>();

    for (const job of list) {
        const prev = latest.get(job.image);
        if (!prev || job.created_at >= prev.created_at) latest.set(job.image, job);
    }

    return [...latest.values()];
};


/* 인증 */

// login 페이지
export const login = async (username : string, password : string) : Promise<TokenPair> => {
    const pair = await post<TokenPair>('/api/v1/auth/login/', { username, password }).catch(
        (error : unknown) => {
            if (error instanceof ApiError && error.status === 401) {
                throw new Error('아이디 또는 비밀번호가 올바르지 않습니다.');
            }
            throw error;
        },
    );

    setSession({ ...pair, staff_id: '' });
    return pair;
};

// header · profile 페이지
export const logout = async () : Promise<void> => {
    const current = getSession();
    setSession(null);

    if (current?.refresh) {
        await post('/api/v1/auth/logout/', { refresh: current.refresh }).catch(() => undefined);
    }
};

// isAuthenticated >> 토큰 유무만. 서버에 묻지 않아 동기
export const isAuthenticated = () : boolean => !!getSession();


/* 의료진 */

// 전 화면
export const getMe = async () : Promise<Staff | null> => {
    const me = await get<Staff>('/api/v1/staff/me/');

    const current = getSession();
    if (current && current.staff_id !== me.id) setSession({ ...current, staff_id: me.id });

    return me;
};

// profile 페이지
export const updateMe = (body : StaffMeUpdate) : Promise<Staff> =>
    patch<Staff>('/api/v1/staff/me/', body);

// profile 페이지
export const changePassword = (body : PasswordChange) : Promise<void> =>
    post<void>('/api/v1/auth/password/change/', body);

// 관리 콘솔 구성원 · 공유 보내기 페이지
export const getStaff = () : Promise<Staff[]> => get<Staff[]>('/api/v1/staff/');

// 관리 콘솔 구성원 페이지 >> 관리자만. 본인 직군은 여기서도 못 바꾼다
export const updateStaff = (
    id : string,
    body : { role? : Role; department? : string },
) : Promise<Staff> => patch<Staff>(`/api/v1/staff/${id}/`, body);

// 관리 콘솔 구성원 페이지
export const deactivateStaff = (id : string) : Promise<Staff> =>
    del<Staff>(`/api/v1/staff/${id}/`);

// profile · 관리 콘솔 부서 · 계정 요청 페이지
export const getDepartments = () : Promise<Department[]> =>
    get<Department[]>('/api/v1/departments/');


/* 환자 */

// 분석 등록 페이지
// 이름·전화번호는 암호화 컬럼이라 해시로 정확히 일치하는 것만 찾힌다.
// 부분 검색이 되는 키는 차트번호뿐이다
export const searchPatients = ({
    chartNumber,
    phone,
    name,
    birthDate,
} : {
    chartNumber? : string;
    phone? : string;
    name? : string;
    birthDate? : string;
}) : Promise<PatientSummary[]> => {
    const params = chartNumber
        ? { chart_number: chartNumber }
        : phone
          ? { phone }
          : name && birthDate
            ? { name, birth_date: birthDate }
            : null;

    if (!params) return Promise.resolve([]);

    return get<PatientSummary[]>(`/api/v1/patients/search/${query(params)}`);
};

// 분석 등록 페이지 >> 워크인 등록
export const registerPatient = (body : PatientCreate) : Promise<PatientSummary> =>
    post<PatientSummary>('/api/v1/patients/', body);


/* 분석 */

// 대시보드 · 판독 목록 · 공유 페이지 >> {count, limit, offset, results} 봉투로 온다
export const getBatches = (params : BatchQuery = {}) : Promise<Paginated<Batch>> =>
    get<Paginated<Batch>>(`/api/v1/analysis/batches/${query({ ...params })}`);

// 배치 요약 · 브레드크럼
export const getBatchDetail = (id : string) : Promise<BatchDetail> =>
    get<BatchDetail>(`/api/v1/analysis/batches/${id}/`);

// getLatestJobs >> ?needs_review=true는 결과가 나온 job 전부라 ABSTAIN만 거르려면 여기서 받는다
export const getLatestJobs = async () : Promise<Job[]> =>
    latestPerImage(await get<Job[]>('/api/v1/analysis/jobs/'));

// 배치 요약 페이지
export const getJobsByBatch = async (batchId : string) : Promise<Job[]> =>
    latestPerImage((await getBatchDetail(batchId)).jobs);

// 결과 상세 페이지
export const getJob = (id : string) : Promise<Job> =>
    get<Job>(`/api/v1/analysis/jobs/${id}/`);

// 판정 유보 검증함 >> 병리의가 ABSTAIN을 LOW/HIGH로 확정한다
export const createJobReview = (
    jobId : string,
    body : JobReviewCreate,
) : Promise<JobReview> =>
    post<JobReview>(`/api/v1/analysis/jobs/${jobId}/review/`, body);

// 분석 등록 페이지 >> 모델 선택
export const getActiveModelVersions = () : Promise<ModelVersion[]> =>
    get<ModelVersion[]>('/api/v1/analysis/model-versions/');

// getModelVersions >> 비활성 포함 조회가 없어 활성만 온다.
export const getModelVersions = getActiveModelVersions;

// 분석 등록 페이지
export const createBatch = (patientId : string) : Promise<Batch> =>
    post<Batch>('/api/v1/analysis/batches/', { patient_id: patientId });

// 분석 등록 페이지 >> 응답에 업로드용 서명 URL이 들어 있다
export const requestUploadUrl = (
    batchId : string,
    originalFilename : string,
) : Promise<ImageUpload> =>
    post<ImageUpload>(`/api/v1/analysis/batches/${batchId}/images/`, {
        original_filename: originalFilename,
    });

// 업로드 큐
export const uploadToSignedUrl = putFile;

// 업로드 큐 >> 파일이 다 올라간 뒤 분석을 건다
export const startBatch = (batchId : string, modelVersionId? : string) : Promise<void> =>
    post<void>(`/api/v1/analysis/batches/${batchId}/start/`, {
        model_version_id: modelVersionId,
    });

// 배치 요약 · 결과 상세 페이지 >> 같은 이미지로 job을 하나 더 만듬
export const retryJob = (imageId : string, modelVersionId? : string) : Promise<Job> =>
    post<Job>(`/api/v1/analysis/images/${imageId}/jobs/`, {
        model_version_id: modelVersionId,
    });


/* 진료 */

// 진료 기록 · 처방 페이지 >> 두 글자 미만이면 서버가 빈 목록을 준다
export const searchDiseases = (q : string) : Promise<Disease[]> =>
    q.trim().length < 2
        ? Promise.resolve([])
        : get<Disease[]>(`/api/v1/diseases/${query({ q: q.trim() })}`);

export const searchDrugs = (q : string) : Promise<Drug[]> =>
    q.trim().length < 2
        ? Promise.resolve([])
        : get<Drug[]>(`/api/v1/drugs/${query({ q: q.trim() })}`);

// 진료 기록 페이지
export const getVisits = (patientId : string) : Promise<Visit[]> =>
    get<Visit[]>(`/api/v1/visits/${query({ patient: patientId })}`);

export const createVisit = (body : VisitCreate) : Promise<Visit> =>
    post<Visit>('/api/v1/visits/', body);

// 처방 페이지
export const getPrescriptions = (
    params : { visit? : string; patient? : string },
) : Promise<Prescription[]> =>
    get<Prescription[]>(`/api/v1/prescriptions/${query({ ...params })}`);

export const createPrescription = (body : PrescriptionCreate) : Promise<Prescription> =>
    post<Prescription>('/api/v1/prescriptions/', body);


/* 계정 요청 */

// 계정 요청 페이지 >> 인증 불필요
export const createAccountRequest = (body : AccountRequestCreate) : Promise<AccountRequest> =>
    post<AccountRequest>('/api/v1/auth/account-requests/', body);

// 관리 콘솔 계정 요청 페이지
export const getAccountRequests = (
    status? : AccountRequestStatus,
) : Promise<AccountRequest[]> =>
    get<AccountRequest[]>(`/api/v1/auth/account-requests/${query({ status })}`);

// approveAccountRequest >> 응답의 temporary_password는 여기서만 온다. 다시 못 받는다
export const approveAccountRequest = (
    id : string,
    body : AccountRequestApprove,
) : Promise<AccountRequestApproved> =>
    post<AccountRequestApproved>(`/api/v1/auth/account-requests/${id}/approve/`, body);

export const rejectAccountRequest = (id : string, reason = '') : Promise<void> =>
    post<void>(`/api/v1/auth/account-requests/${id}/reject/`, { reason });


/* 알림 */

// 알림 페이지 · 사이드바 배지
export const getNotifications = async () : Promise<AppNotification[]> => {
    const list = await get<AppNotification[]>('/api/v1/notifications/');

    return list.sort((a, b) => b.created_at.localeCompare(a.created_at));
};

export const markNotificationRead = (id : string) : Promise<void> =>
    patch<void>(`/api/v1/notifications/${id}/`);

export const markAllNotificationsRead = () : Promise<void> =>
    post<void>('/api/v1/notifications/read-all/');


/* 공유 */

// 보낸 공유 페이지
export const getSharesSentByMe = () : Promise<AnalysisShare[]> =>
    get<AnalysisShare[]>(`/api/v1/analysis/shares/${query({ direction: 'sent' })}`);

// 받은 공유 페이지
export const getSharesToMe = () : Promise<AnalysisShare[]> =>
    get<AnalysisShare[]>(`/api/v1/analysis/shares/${query({ direction: 'received' })}`);

// 공유 보내기 페이지
export const createShare = (
    batchId : string,
    body : AnalysisShareCreate,
) : Promise<AnalysisShare> =>
    post<AnalysisShare>(`/api/v1/analysis/batches/${batchId}/shares/`, body);

// 공유 보내기 페이지 >> 물리 삭제가 아니라 revoked_at이 찍힌다
export const revokeShare = (shareId : string) : Promise<void> =>
    del<void>(`/api/v1/analysis/shares/${shareId}/`);
