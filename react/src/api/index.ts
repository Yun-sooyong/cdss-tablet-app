import type { Batch, ImageUpload, Job, ModelVersion } from '@/api/types';
import { mockBatches, mockImages, mockJobs, mockModelVersions } from './fixtures';

// 화면은 api/fixtures 가 아니라 여기서만 데이터를 가져온다.
// 실제 API를 붙일 때 이 파일 안쪽만 바꾼다.

export const getJobs = (): Job[] => mockJobs;

export const getJob = (id: string): Job | undefined =>
    mockJobs.find((j) => j.id === id);

export const getBatches = (): Batch[] => mockBatches;

export const getBatch = (id: string): Batch | undefined =>
    mockBatches.find((b) => b.id === id);

export const getModelVersions = (): ModelVersion[] => mockModelVersions;

export const getActiveModelVersions = (): ModelVersion[] =>
    mockModelVersions.filter((m) => m.is_active);

// getImage >> Job에 batch 필드가 없어 image를 거쳐야 배치를 알 수 있음
export const getImage = (id: string): ImageUpload | undefined =>
    mockImages.find((i) => i.id === id);

export const getImagesByBatch = (batchId: string): ImageUpload[] =>
    mockImages.filter((i) => i.batch === batchId);

export const getJobsByBatch = (batchId: string): Job[] => {
    const imageIds = new Set(getImagesByBatch(batchId).map((i) => i.id));
    return mockJobs.filter((j) => imageIds.has(j.image));
};
