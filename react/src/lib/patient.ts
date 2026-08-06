import type { PatientSummary, Sex } from '@/api/types';

export const SEX_LABEL : Record<Sex, string> = {
    M: '남',
    F: '여',
    O: '기타',
    U: '미상',
};

// 목록용 >> 이름만. 차트번호는 케이스를 열면 상세 머리말에 나온다
export const patientBrief = (p : PatientSummary) : string => p.name;

// 상세용 >> 차트번호 · 이름 · 생년월일 · 성별
export const patientFull = (p : PatientSummary) : string =>
    `${p.chart_number} · ${p.name} · ${p.birth_date} (${SEX_LABEL[p.sex]})`;

export const UNLINKED = '환자 미연결';

// patientLabel
export const patientLabel = (p : PatientSummary | null) : string =>
    p ? patientBrief(p) : UNLINKED;

// patientLabelFull
export const patientLabelFull = (p : PatientSummary | null) : string =>
    p ? patientFull(p) : UNLINKED;
