import type {
    AnalysisShare,
    AnalysisShareCreate,
    AppNotification,
    Batch,
    BatchDetail,
    Department,
    ImageUpload,
    Invitation,
    InvitationIssue,
    InvitationRedeem,
    Job,
    JobResult,
    ModelVersion,
    PasswordChange,
    PatientSummary,
    Staff,
    StaffMeUpdate,
    TokenPair,
} from '@/api/types';
import { CUTOFF } from '@/lib/decision';
import { isTerminal } from '@/lib/jobStatus';
import {
    mockBatches,
    mockDepartments,
    mockImages,
    mockInvitations,
    mockJobs,
    mockModelVersions,
    mockNotifications,
    mockPatients,
    mockShares,
    mockStaff,
} from './fixtures';

const batches : Batch[] = [...mockBatches];
const images : ImageUpload[] = [...mockImages];
const jobs : Job[] = [...mockJobs];
const staff : Staff[] = [...mockStaff];
const notifications : AppNotification[] = [...mockNotifications];
const shares : AnalysisShare[] = [...mockShares];
const invitations : Invitation[] = [...mockInvitations];

const uuid = () => crypto.randomUUID();

/* 목 API >> 함수마다 대응 엔드포인트를 주석으로 단다. 서버 연결 시 이 파일만 바뀐다 */

const LATENCY_MS = 120;

const reply = <T>(value : T) : Promise<T> =>
    new Promise((resolve) => setTimeout(() => resolve(value), LATENCY_MS));

const fail = (message : string) : Promise<never> =>
    new Promise((_, reject) => setTimeout(() => reject(new Error(message)), LATENCY_MS));

// 내부 동기 조회
const imagesOf = (batchId : string) : ImageUpload[] =>
    images.filter((i) => i.batch === batchId);

const allJobsOf = (batchId : string) : Job[] => {
    const ids = new Set(imagesOf(batchId).map((i) => i.id));

    return jobs
        .filter((j) => ids.has(j.image))
        .sort((a, b) => b.created_at.localeCompare(a.created_at));
};

// latestPerImage >> image당 최신 job 하나
export const latestPerImage = (list : Job[]) : Job[] => {
    const latest = new Map<string, Job>();

    for (const job of list) {
        const prev = latest.get(job.image);
        if (!prev || job.created_at >= prev.created_at) latest.set(job.image, job);
    }

    return [...latest.values()];
};

// GET /analysis/batches/ >> 본인 것 + 공유받은 것
export const getBatches = () : Promise<Batch[]> => reply([...batches]);

// GET /analysis/batches/{id}/ >> 배치에 job 목록이 딸려 온다
export const getBatchDetail = (id : string) : Promise<BatchDetail> => {
    const batch = batches.find((b) => b.id === id);
    if (!batch) return fail('해당 배치를 찾을 수 없습니다.');

    return reply({ ...batch, jobs: allJobsOf(id) });
};

// getJobsByBatch >> 배치 상세에서 image당 최신 job만
export const getJobsByBatch = (batchId : string) : Promise<Job[]> =>
    reply(latestPerImage(allJobsOf(batchId)));

// getLatestJobs >> 전 배치의 최신 job. 대응 엔드포인트 없음
export const getLatestJobs = () : Promise<Job[]> =>
    reply(batches.flatMap((b) => latestPerImage(allJobsOf(b.id))));

// GET /analysis/jobs/{id}/
export const getJob = (id : string) : Promise<Job> => {
    const job = jobs.find((j) => j.id === id);
    return job ? reply(job) : fail('해당 분석 결과를 찾을 수 없습니다.');
};

// getImage · getImages >> 조회 엔드포인트 없음. 화면이 쓰는 original_filename의 출처
export const getImage = (id : string) : Promise<ImageUpload | undefined> =>
    reply(images.find((i) => i.id === id));

export const getImages = () : Promise<ImageUpload[]> => reply(images);

const activeModels = () : ModelVersion[] => mockModelVersions.filter((m) => m.is_active);

// GET /analysis/model-versions/ >> 활성만 온다
export const getActiveModelVersions = () : Promise<ModelVersion[]> => reply(activeModels());

// getModelVersions >> 비활성 포함 전체. 대응 엔드포인트 없음
export const getModelVersions = () : Promise<ModelVersion[]> => reply(mockModelVersions);

// GET /patients/search/ >> 차트번호는 부분일치, 전화번호는 해시 정확일치
export const searchPatients = ({
    chartNumber,
    phone,
} : {
    chartNumber? : string;
    phone? : string;
}) : Promise<PatientSummary[]> => {
    if (!chartNumber && !phone) return reply([]);

    return reply(
        mockPatients
            .filter((p) =>
                chartNumber
                    ? p.chart_number.toLowerCase().includes(chartNumber.toLowerCase())
                    : false,
            )
            .sort((a, b) => a.chart_number.localeCompare(b.chart_number))
            .slice(0, 20),
    );
};

// POST /analysis/batches/
export const createBatch = (patientId : string) : Promise<Batch> => {
    const patient = mockPatients.find((p) => p.id === patientId) ?? null;
    const now = new Date().toISOString();

    const batch : Batch = {
        id: uuid(),
        patient: patientId,
        patient_summary: patient,
        status: 'pending',
        created_by: 'e2c7a940-3b18-4d6f-a052-7f9c1e8b4a33',
        created_at: now,
        updated_at: now,
    };

    batches.unshift(batch);
    return reply(batch);
};

// POST /analysis/batches/{id}/images/ >> 응답에 업로드용 서명 URL이 들어 있다
export const requestUploadUrl = (
    batchId : string,
    originalFilename : string,
) : Promise<ImageUpload> => {
    const id = uuid();
    const key = `uploads/${batchId}/${id}`;

    const image : ImageUpload = {
        id,
        batch: batchId,
        storage_key: key,
        original_filename: originalFilename,
        created_at: new Date().toISOString(),
        upload_url: `https://mock-upload.local/${key}`,
    };

    images.push(image);
    return reply(image);
};

// uploadToSignedUrl
export const uploadToSignedUrl = (
    _url : string,
    _file : File,
    onProgress : (percent : number) => void,
) : Promise<void> =>
    new Promise((resolve) => {
        let percent = 0;
        const step = () => {
            percent = Math.min(100, percent + 6 + Math.random() * 12);
            onProgress(percent);
            if (percent >= 100) resolve();
            else setTimeout(step, 200);
        };
        setTimeout(step, 200);
    });

/* 분석 시뮬레이션 */

const STEP_MS = 1200;

const round1 = (n : number) : number => Math.round(n * 10) / 10;

const simulateComposition = () => {
    const raw = [
        40 + Math.random() * 20,
        20 + Math.random() * 15,
        8 + Math.random() * 12,
        3 + Math.random() * 8,
        2 + Math.random() * 6,
    ];
    const sum = raw.reduce((a, b) => a + b, 0);
    const [tumor, stroma, immune, necrosis] = raw.map((n) => round1((n / sum) * 100));

    return {
        tumor,
        stroma,
        immune,
        necrosis,
            // other >> 반올림 오차 흡수
        other: round1(100 - tumor - stroma - immune - necrosis),
    };
};

const simulateResult = () : JobResult => {
    const stil = round1(5 + Math.random() * 90);
    const sigma = round1(3 + Math.random() * 7);
    const lower = round1(stil - 2 * sigma);
    const upper = round1(stil + 2 * sigma);

    // ABSTAIN >> 구간이 컷오프를 가로지름
    const abstain = lower <= CUTOFF && CUTOFF <= upper;

    return {
        stil_value: stil,
        sigma,
        lower,
        upper,
        abstain,
        decision: abstain ? 'ABSTAIN' : stil < CUTOFF ? 'LOW' : 'HIGH',
        cp_value: round1(0.8 + Math.random() * 0.19),
        n_valid: Math.round(80 + Math.random() * 160),
        class_composition: simulateComposition(),
    };
};

const simulateReport = (result : JobResult) : string =>
    result.decision === 'ABSTAIN'
        ? `sTIL ${result.stil_value}%로 추정되나 예측 구간(${result.lower}~${result.upper}%)이 컷오프 ${CUTOFF}%를 포함합니다. 육안 확인을 권합니다.`
        : `sTIL ${result.stil_value}%로 컷오프 ${CUTOFF}% 대비 ${result.decision === 'HIGH' ? '높은' : '낮은'} 수준입니다. 유효 타일 ${result.n_valid}개 기준입니다.`;

// 배치 종료 판정
const settleBatch = (batchId : string) : void => {
    const batch = batches.find((b) => b.id === batchId);
    if (!batch) return;

    const mine = latestPerImage(allJobsOf(batchId));
    if (mine.length === 0 || !mine.every((j) => isTerminal(j.status))) return;

    batch.status = mine.every((j) => j.status === 'failed') ? 'failed' : 'done';
    batch.updated_at = new Date().toISOString();
};

const simulateJob = (jobId : string, batchId : string) : void => {
    const find = () => jobs.find((j) => j.id === jobId);

    setTimeout(() => {
        const job = find();
        if (job?.status !== 'queued') return;

        job.status = 'running';
        job.started_at = new Date().toISOString();
    }, STEP_MS);

    // stil_done >> 1차 콜백. 값만 있고 리포트 없음
    setTimeout(() => {
        const job = find();
        if (job?.status !== 'running') return;

        job.status = 'stil_done';
        job.result = simulateResult();
    }, STEP_MS * 3);

    setTimeout(() => {
        const job = find();
        if (job?.status !== 'stil_done' || !job.result) return;

        job.result.medgemma_report = {
            summary: simulateReport(job.result),
            generation_failed: false,
        };
        job.status = 'succeeded';
        job.finished_at = new Date().toISOString();

        settleBatch(batchId);
    }, STEP_MS * 5);
};

// POST /analysis/batches/{id}/start/
export const startBatch = (
    batchId : string,
    modelVersionId? : string,
) : Promise<void> => {
    const batch = batches.find((b) => b.id === batchId);
    if (!batch) return fail('해당 배치를 찾을 수 없습니다.');

    const modelVersion =
        modelVersionId ?? activeModels()[0]?.id ?? mockModelVersions[0].id;

    for (const image of imagesOf(batchId)) {
        if (jobs.some((j) => j.image === image.id)) continue;

        const job : Job = {
            id: uuid(),
            image: image.id,
            model_version: modelVersion,
            status: 'queued',
            result: null,
            patient_summary: batch.patient_summary,
            error_message: '',
            started_at: null,
            finished_at: null,
            created_at: new Date().toISOString(),
        };

        jobs.push(job);
        simulateJob(job.id, batchId);
    }

    batch.status = 'processing';
    batch.updated_at = new Date().toISOString();

    return reply(undefined);
};

// POST /analysis/images/{id}/jobs/ >> 같은 이미지로 job을 하나 더 만든다
export const retryJob = (
    imageId : string,
    modelVersionId? : string,
) : Promise<Job> => {
    const image = images.find((i) => i.id === imageId);
    if (!image) return fail('해당 슬라이드를 찾을 수 없습니다.');

    const batch = batches.find((b) => b.id === image.batch);

    const previous = latestPerImage(jobs).find((j) => j.image === imageId);
    const modelVersion =
        modelVersionId ??
        previous?.model_version ??
        activeModels()[0]?.id ??
        mockModelVersions[0].id;

    const job : Job = {
        id: uuid(),
        image: imageId,
        model_version: modelVersion,
        status: 'queued',
        result: null,
        patient_summary: batch?.patient_summary ?? null,
        error_message: '',
        started_at: null,
        finished_at: null,
        created_at: new Date().toISOString(),
    };

    jobs.push(job);

    if (batch) {
        batch.status = 'processing';
        batch.updated_at = job.created_at;
        simulateJob(job.id, batch.id);
    }

    return reply(job);
};


/* 인증 */

const SESSION_KEY = 'cdss.session';

interface Session {
    access : string;
    refresh : string;
    staff_id : string;
}

const readSession = () : Session | null => {
    try {
        const raw = localStorage.getItem(SESSION_KEY);
        return raw ? (JSON.parse(raw) as Session) : null;
    } catch {
        return null;
    }
};

let session : Session | null = readSession();

// POST /auth/login/
export const login = (username : string, password : string) : Promise<TokenPair> => {
    const found = staff.find((s) => s.username === username);
    if (!found || !password) return fail('아이디 또는 비밀번호가 올바르지 않습니다.');
    if (found.employment_status === 'resigned') return fail('퇴사 처리된 계정입니다.');

    const pair : TokenPair = { access: `mock-access-${uuid()}`, refresh: `mock-refresh-${uuid()}` };
    session = { ...pair, staff_id: found.id };
    localStorage.setItem(SESSION_KEY, JSON.stringify(session));

    return reply(pair);
};

// POST /auth/logout/ >> refresh 토큰 폐기
export const logout = () : Promise<void> => {
    session = null;
    localStorage.removeItem(SESSION_KEY);

    return reply(undefined);
};

// isAuthenticated >> 토큰 유무만. 서버에 묻지 않아 동기
export const isAuthenticated = () : boolean => !!session;


/* 의료진 */

const meSync = () : Staff | null =>
    staff.find((s) => s.id === session?.staff_id) ?? null;

// GET /staff/me/
export const getMe = () : Promise<Staff | null> => reply(meSync());

// PATCH /staff/me/ >> department만. role은 서버가 막는다
export const updateMe = (patch : StaffMeUpdate) : Promise<Staff> => {
    const me = meSync();
    if (!me) return fail('로그인이 필요합니다.');

    if (patch.department !== undefined) me.department = patch.department;
    return reply(me);
};

// GET /staff/ >> 재직자만
export const getStaff = () : Promise<Staff[]> =>
    reply(staff.filter((s) => s.employment_status === 'active'));

// DELETE /staff/{id}/ >> 삭제가 아니라 퇴사 처리(resigned). 관리자만
export const deactivateStaff = (id : string) : Promise<Staff> => {
    const found = staff.find((s) => s.id === id);
    if (!found) return fail('해당 계정을 찾을 수 없습니다.');

    found.employment_status = 'resigned';
    found.resigned_at = new Date().toISOString().slice(0, 10);

    return reply(found);
};

// POST /auth/password/change/ >> 본인 비밀번호
export const changePassword = (body : PasswordChange) : Promise<void> => {
    if (!body.old_password) return fail('현재 비밀번호를 입력해 주세요.');
    if (body.new_password.length < 8) return fail('새 비밀번호는 8자 이상이어야 합니다.');
    if (body.new_password === body.old_password) {
        return fail('현재 비밀번호와 다른 값을 입력해 주세요.');
    }

    return reply(undefined);
};

// GET /departments/
export const getDepartments = () : Promise<Department[]> => reply(mockDepartments);


/* 초대코드 */

const CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

// issuedInvitations >> 목록 엔드포인트 없음. 발급 응답만 모은다
const issuedInvitations : Invitation[] = [];

// POST /staff/invitations/ >> 관리자만
export const issueInvitation = (body : InvitationIssue) : Promise<Invitation> => {
    const days = body.expires_in_days ?? 7;
    const expires = new Date();
    expires.setDate(expires.getDate() + days);

    const code = Array.from(
        crypto.getRandomValues(new Uint8Array(8)),
        (n) => CODE_CHARS[n % CODE_CHARS.length],
    ).join('');

    const invitation : Invitation = {
        code,
        role: body.role,
        department: body.department ?? '',
        expires_at: expires.toISOString(),
        is_used: false,
        created_at: new Date().toISOString(),
    };

    invitations.unshift(invitation);
    issuedInvitations.unshift(invitation);

    return reply(invitation);
};

export const getIssuedInvitations = () : Promise<Invitation[]> => reply(issuedInvitations);

// POST /auth/invitations/redeem/ >> 로그인 불필요
export const redeemInvitation = (body : InvitationRedeem) : Promise<void> => {
    const invitation = invitations.find((i) => i.code === body.code.toUpperCase());
    if (!invitation) return fail('초대코드를 찾을 수 없습니다.');
    if (invitation.is_used) return fail('이미 사용된 초대코드입니다.');
    if (new Date(invitation.expires_at) < new Date()) return fail('만료된 초대코드입니다.');
    if (staff.some((s) => s.username === body.username)) return fail('이미 사용 중인 아이디입니다.');

    staff.push({
        id: uuid(),
        username: body.username,
        email: body.email,
        role: invitation.role,
        department: invitation.department,
        employment_status: 'active',
        resigned_at: null,
        created_at: new Date().toISOString(),
    });

    invitation.is_used = true;
    return reply(undefined);
};


/* 알림 */

// GET /notifications/ >> 본인 것만
export const getNotifications = () : Promise<AppNotification[]> =>
    reply([...notifications].sort((a, b) => b.created_at.localeCompare(a.created_at)));

// markNotificationRead · markAllNotificationsRead >> 대응 엔드포인트 없음
export const markNotificationRead = (id : string) : Promise<void> => {
    const found = notifications.find((n) => n.id === id);
    if (found) found.is_read = true;

    return reply(undefined);
};

export const markAllNotificationsRead = () : Promise<void> => {
    for (const n of notifications) n.is_read = true;

    return reply(undefined);
};


/* 공유 */

const isShareLive = (share : AnalysisShare) : boolean =>
    !share.revoked_at && (!share.expires_at || new Date(share.expires_at) > new Date());

// getSharesSentByMe · getSharesToMe >> 대응 엔드포인트 없음
export const getSharesSentByMe = () : Promise<AnalysisShare[]> =>
    reply(
        shares
            .filter((s) => s.shared_by === session?.staff_id)
            .sort((a, b) => b.created_at.localeCompare(a.created_at)),
    );

export const getSharesToMe = () : Promise<AnalysisShare[]> =>
    reply(
        shares
            .filter((s) => s.shared_to === session?.staff_id)
            .sort((a, b) => b.created_at.localeCompare(a.created_at)),
    );

// POST /analysis/batches/{id}/shares/
export const createShare = (
    batchId : string,
    body : AnalysisShareCreate,
) : Promise<AnalysisShare> => {
    const live = shares.find(
        (s) => s.batch === batchId && s.shared_to === body.shared_to && isShareLive(s),
    );
    if (live) return fail('이미 공유된 상대입니다.');

    const share : AnalysisShare = {
        id: uuid(),
        batch: batchId,
        shared_by: session?.staff_id ?? '',
        shared_to: body.shared_to,
        permission: body.permission ?? 'read',
        expires_at: body.expires_at ?? null,
        revoked_at: null,
        created_at: new Date().toISOString(),
    };

    shares.unshift(share);
    return reply(share);
};

// DELETE /analysis/shares/{id}/ >> 물리 삭제가 아니라 revoked_at이 찍힌다
export const revokeShare = (shareId : string) : Promise<void> => {
    const found = shares.find((s) => s.id === shareId);
    if (!found) return fail('해당 공유를 찾을 수 없습니다.');

    found.revoked_at = new Date().toISOString();
    return reply(undefined);
};