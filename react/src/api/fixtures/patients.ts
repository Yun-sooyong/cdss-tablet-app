import type { PatientSummary } from '@/api/types';

// chart_number >> 평문 인덱스 컬럼. 부분검색이 가능한 유일한 키다.
export const mockPatients : PatientSummary[] = [
    {
        id: '247a0651-c7e4-4ec5-9bad-72b8e3d8f201',
        chart_number: 'PA1B2C3D4',
        name: '김민수',
        birth_date: '1978-03-14',
        sex: 'M',
    },
    {
        id: '247a0651-c7e4-4ec5-9bad-72b8e3d8f202',
        chart_number: 'PE56EA6F7',
        name: '이수진',
        birth_date: '1990-01-01',
        sex: 'F',
    },
    {
        id: '247a0651-c7e4-4ec5-9bad-72b8e3d8f203',
        chart_number: 'P9F2D0C31',
        name: '박준호',
        birth_date: '1965-11-02',
        sex: 'M',
    },
];

export const [PATIENT_1, PATIENT_2, PATIENT_3] = mockPatients;