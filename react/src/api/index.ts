import type {
    Batch,
    ImageUpload,
    Job,
    ModelVersion,
    PatientSummary,
} from '@/api/types';
import {
    mockBatches,
    mockImages,
    mockJobs,
    mockModelVersions,
    mockPatients,
} from './fixtures';

// 화면은 api/fixtures 가 아니라 여기서만 데이터를 가져온다.
// 실제 API를 붙일 때 이 파일 안쪽만 바꾼다.

// 생성 흐름을 목업에서도 돌려보려면 쓰기가 가능해야 한다.
// 실제 API를 붙이면 이 배열들은 사라지고 fetch 로 바뀐다.
const batches : Batch[] = [...mockBatches];
const images : ImageUpload[] = [...mockImages];
const jobs : Job[] = [...mockJobs];

const uuid = () => crypto.randomUUID();

export const getJobs = () : Job[] => jobs;

export const getJob = (id : string) : Job | undefined =>
    jobs.find((j) => j.id === id);

export const getBatches = () : Batch[] => batches;

export const getBatch = (id : string) : Batch | undefined =>
    batches.find((b) => b.id === id);

export const getModelVersions = () : ModelVersion[] => mockModelVersions;

export const getActiveModelVersions = () : ModelVersion[] =>
    mockModelVersions.filter((m) => m.is_active);

// getImage >> Job에 batch 필드가 없어 image를 거쳐야 배치를 알 수 있음
export const getImage = (id : string) : ImageUpload | undefined =>
    images.find((i) => i.id === id);

export const getImagesByBatch = (batchId : string) : ImageUpload[] =>
    images.filter((i) => i.batch === batchId);

export const getJobsByBatch = (batchId : string) : Job[] => {
    const imageIds = new Set(getImagesByBatch(batchId).map((i) => i.id));
    return jobs.filter((j) => imageIds.has(j.image));
};

// searchPatients >> 서버는 chart_number 부분일치와 phone 완전일치만 지원한다.
// 이름 생년월일은 암호화 컬럼이라 DB 레벨 검색이 불가능하다.
export const searchPatients = ({
    chartNumber,
    phone,
} : {
    chartNumber? : string;
    phone? : string;
}) : PatientSummary[] => {
    if (!chartNumber && !phone) return [];

    return mockPatients
        .filter((p) => {
            if (chartNumber) {
                return p.chart_number.toLowerCase().includes(chartNumber.toLowerCase());
            }
            return false;
        })
        .sort((a, b) => a.chart_number.localeCompare(b.chart_number))
        .slice(0, 20);
};

export const createBatch = (patientId : string) : Batch => {
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
    return batch;
};

export const requestUploadUrl = (
    batchId : string,
    originalFilename : string,
) : ImageUpload => {
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
    return image;
};

// uploadToSignedUrl >> 실제로는 XHR PUT 으로 진행률을 받는다.
// 목업에서는 타이머로 진행률만 흉내낸다.
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

export const startBatch = (batchId : string, modelVersionId? : string) : void => {
    const batch = batches.find((b) => b.id === batchId);
    if (!batch) return;

    const modelVersion =
        modelVersionId ?? getActiveModelVersions()[0]?.id ?? mockModelVersions[0].id;

    for (const image of getImagesByBatch(batchId)) {
        if (jobs.some((j) => j.image === image.id)) continue;

        jobs.push({
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
        });
    }

    batch.status = 'processing';
    batch.updated_at = new Date().toISOString();
};