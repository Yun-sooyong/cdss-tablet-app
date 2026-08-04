import type { PatientSummary, Sex } from '@/api/types';

export const SEX_LABEL : Record<Sex, string> = {
    M: '남',
    F: '여',
    O: '기타',
    U: '미상',
};

// 목록용 >> 차트번호와 이름만. 생년월일까지 넣으면 행이 좁아진다
export const patientBrief = (p : PatientSummary) : string =>
    `${p.chart_number} · ${p.name}`;

// 상세용 >> 판독 맥락에 필요한 전부
export const patientFull = (p : PatientSummary) : string =>
    `${p.chart_number} · ${p.name} · ${p.birth_date} (${SEX_LABEL[p.sex]})`;
