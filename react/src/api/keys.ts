/* TanStack Query 키 */
export const qk = {
    me: ['me'] as const,
    staff: ['staff'] as const,
    departments: ['departments'] as const,
    accountRequests: (status? : string) => ['account-requests', status ?? 'all'] as const,
    modelVersions: ['model-versions'] as const,

    notifications: ['notifications'] as const,

    // batches >> 무효화용 접두사. 아래 목록·상세 키가 전부 이 아래 붙는다
    batches: ['batches'] as const,
    // batchList >> 필터마다 캐시가 갈린다. 서버가 걸러 주므로 조건이 키에 들어가야 한다
    batchList: (params : { status? : string; q? : string } = {}) =>
        ['batches', 'list', params] as const,
    batch: (id : string) => ['batches', id] as const,
    jobsByBatch: (id : string) => ['batches', id, 'jobs'] as const,
    latestJobs: ['jobs', 'latest'] as const,
    job: (id : string) => ['jobs', id] as const,

    sharesIn: ['shares', 'in'] as const,
    sharesOut: ['shares', 'out'] as const,

    patients: ['patients'] as const,
    patientSearch: (query : string) => ['patients', 'search', query] as const,
};
