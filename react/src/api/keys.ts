/* TanStack Query 키 */
export const qk = {
    me: ['me'] as const,
    staff: ['staff'] as const,
    departments: ['departments'] as const,
    accountRequests: (status? : string) => ['account-requests', status ?? 'all'] as const,
    modelVersions: ['model-versions'] as const,

    notifications: ['notifications'] as const,

    batches: ['batches'] as const,
    batch: (id : string) => ['batches', id] as const,
    jobsByBatch: (id : string) => ['batches', id, 'jobs'] as const,
    latestJobs: ['jobs', 'latest'] as const,
    job: (id : string) => ['jobs', id] as const,

    sharesIn: ['shares', 'in'] as const,
    sharesOut: ['shares', 'out'] as const,

    patients: ['patients'] as const,
    patientSearch: (query : string) => ['patients', 'search', query] as const,
};
