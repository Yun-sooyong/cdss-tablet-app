// 진료 기록 >> 환자를 고르고 소견·진단을 남긴다
import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Search, X } from 'lucide-react';
import { toast } from 'sonner';

import {
    createVisit,
    getDepartments,
    getVisits,
    searchDiseases,
    searchPatients,
} from '@/api';
import { qk } from '@/api/keys';
import type { Disease, PatientSummary } from '@/api/types';
import { CodeSearchField } from '@/components/CodeSearchField';
import { BUTTON_PRIMARY, FIELD_INPUT, ICON_BUTTON } from '@/components/form';
import { Empty, Failed, Pending } from '@/components/QueryState';
import { formatShort } from '@/lib/format';
import { patientFull } from '@/lib/patient';
import { cn } from '@/lib/utils';

interface Picked {
    disease : Disease;
    is_primary : boolean;
}

export default function VisitsPage() {
    const navigate = useNavigate();
    const queryClient = useQueryClient();

    const [patient, setPatient] = useState<PatientSummary | null>(null);

    return (
        <div className="max-w-3xl">
            {patient ? (
                <>
                    <div className="mb-6 flex items-center justify-between gap-3 rounded-lg border border-border px-4 py-3">
                        <span className="min-w-0 truncate text-base">
                            {patientFull(patient)}
                        </span>
                        <button
                            type="button"
                            onClick={() => setPatient(null)}
                            aria-label="다른 환자 고르기"
                            className={ICON_BUTTON}
                        >
                            <X size={16} />
                        </button>
                    </div>

                    <VisitForm
                        patient={patient}
                        onCreated={(visitId) => {
                            void queryClient.invalidateQueries({
                                queryKey: qk.visits(patient.id),
                            });
                            navigate(`/prescriptions?visit=${visitId}`);
                        }}
                    />

                    <VisitHistory patientId={patient.id} />
                </>
            ) : (
                <PatientPicker onPick={setPatient} />
            )}
        </div>
    );
}

// 이름·전화번호는 암호화 컬럼이라 서버가 부분 검색을 못 한다.
// 부분 입력이 되는 건 차트번호뿐이고 나머지는 정확히 맞아야 찾힌다
const SEARCH_MODES = [
    { value: 'chart', label: '차트번호' },
    { value: 'phone', label: '전화번호' },
    { value: 'name', label: '이름 + 생년월일' },
] as const;

type SearchMode = (typeof SEARCH_MODES)[number]['value'];

function PatientPicker({ onPick } : { onPick : (p : PatientSummary) => void }) {
    const [mode, setMode] = useState<SearchMode>('chart');
    const [draft, setDraft] = useState('');
    const [birthDate, setBirthDate] = useState('');
    const [q, setQ] = useState('');

    useEffect(() => {
        const id = setTimeout(() => setQ(draft.trim()), 300);
        return () => clearTimeout(id);
    }, [draft]);

    // 이름은 생년월일이 같이 있어야 조회가 성립한다
    const ready = mode === 'name' ? !!q && !!birthDate : !!q;
    const params =
        mode === 'chart'
            ? { chartNumber: q }
            : mode === 'phone'
              ? { phone: q }
              : { name: q, birthDate };

    const results = useQuery({
        queryKey: qk.patientSearch(`${mode}:${q}:${birthDate}`),
        queryFn: () => searchPatients(params),
        enabled: ready,
    });

    function switchMode(next : SearchMode) {
        setMode(next);
        setDraft('');
        setBirthDate('');
        setQ('');
    }

    return (
        <div>
            <div className="mb-3 flex w-fit items-center gap-0.5 rounded-md border border-border p-0.5">
                {SEARCH_MODES.map((m) => (
                    <button
                        key={m.value}
                        type="button"
                        onClick={() => switchMode(m.value)}
                        aria-pressed={mode === m.value}
                        className={cn(
                            'flex h-8 items-center rounded px-3 text-sm transition-colors',
                            mode === m.value
                                ? 'bg-surface-raised font-medium text-ink shadow-sm'
                                : 'text-ink-muted hover:bg-ink/[0.04] hover:text-ink',
                        )}
                    >
                        {m.label}
                    </button>
                ))}
            </div>

            <div className={cn('gap-3', mode === 'name' && 'grid md:grid-cols-2')}>
                <label className="block">
                    <span className="mb-1.5 block text-xs text-ink-muted">
                        {mode === 'chart' ? '차트번호' : mode === 'phone' ? '전화번호' : '이름'}
                    </span>
                    <span className="relative block">
                        <Search
                            size={15}
                            className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-ink-faint"
                        />
                        <input
                            value={draft}
                            onChange={(e) => setDraft(e.target.value)}
                            placeholder={
                                mode === 'chart'
                                    ? '일부만 입력해도 됩니다'
                                    : mode === 'phone'
                                      ? '010-0000-0000'
                                      : '홍길동'
                            }
                            className={`${FIELD_INPUT} pl-9`}
                        />
                    </span>
                </label>

                {mode === 'name' && (
                    <label className="block">
                        <span className="mb-1.5 block text-xs text-ink-muted">생년월일</span>
                        <input
                            type="date"
                            value={birthDate}
                            onChange={(e) => setBirthDate(e.target.value)}
                            className={FIELD_INPUT}
                        />
                    </label>
                )}
            </div>

            <p className="mt-2 text-xs text-ink-faint">
                차트번호는 일부만 입력해도 찾습니다. 전화번호와 이름·생년월일은
                정확히 일치해야 합니다 — 개인정보가 암호화돼 있어 부분 검색이 안 됩니다
            </p>

            {ready && results.isSuccess && (
                <div className="mt-2 divide-y divide-border rounded-md border border-border">
                    {results.data.length === 0 ? (
                        <p className="px-3 py-6 text-center text-sm text-ink-faint">
                            찾는 환자가 없습니다
                        </p>
                    ) : (
                        results.data.map((p) => (
                            <button
                                key={p.id}
                                type="button"
                                onClick={() => onPick(p)}
                                className="block w-full px-3 py-2.5 text-left text-sm transition-colors hover:bg-brand-soft/50"
                            >
                                {patientFull(p)}
                            </button>
                        ))
                    )}
                </div>
            )}
        </div>
    );
}

function VisitForm({
    patient,
    onCreated,
} : {
    patient : PatientSummary;
    onCreated : (visitId : string) => void;
}) {
    const { data: departments } = useQuery({
        queryKey: qk.departments,
        queryFn: getDepartments,
    });

    const [department, setDepartment] = useState('');
    const [note, setNote] = useState('');
    const [picked, setPicked] = useState<Picked[]>([]);

    const save = useMutation({
        mutationFn: () =>
            createVisit({
                patient: patient.id,
                department: department || null,
                note: note.trim(),
                diagnoses: picked.map((d) => ({
                    disease: d.disease.code,
                    is_primary: d.is_primary,
                })),
            }),
        onSuccess: (visit) => {
            setNote('');
            setPicked([]);
            toast.success('진료 기록을 남겼습니다', { description: '처방을 이어서 등록합니다' });
            onCreated(visit.id);
        },
        onError: (error : Error) =>
            toast.error('저장하지 못했습니다', { description: error.message }),
    });

    // 주진단은 하나뿐이다
    function setPrimary(code : string) {
        setPicked((prev) =>
            prev.map((d) => ({ ...d, is_primary: d.disease.code === code })),
        );
    }

    return (
        <section className="mb-10">
            <h2 className="mb-3 text-base font-medium">새 진료 기록</h2>

            <div className="space-y-4 rounded-lg border border-border p-4">
                <div className="grid gap-3 md:grid-cols-2">
                    <label className="block">
                        <span className="mb-1.5 block text-xs text-ink-muted">진료과</span>
                        <select
                            value={department}
                            onChange={(e) => setDepartment(e.target.value)}
                            className={FIELD_INPUT}
                        >
                            <option value="">미지정</option>
                            {(departments ?? []).map((d) => (
                                <option key={d.dept_code} value={d.dept_code}>
                                    {d.name}
                                </option>
                            ))}
                        </select>
                    </label>
                </div>

                <label className="block">
                    <span className="mb-1.5 block text-xs text-ink-muted">소견</span>
                    <textarea
                        value={note}
                        onChange={(e) => setNote(e.target.value)}
                        rows={4}
                        placeholder="진료 내용을 남겨 주세요"
                        className={`${FIELD_INPUT} h-auto resize-y py-2 leading-relaxed`}
                    />
                </label>

                <div>
                    <CodeSearchField
                        label="진단명 (선택)"
                        placeholder="병명 또는 코드"
                        queryKey={qk.diseaseSearch}
                        search={searchDiseases}
                        codeOf={(d) => d.code}
                        labelOf={(d) => d.name_ko}
                        hintOf={(d) => d.name_en}
                        onPick={(disease) =>
                            setPicked((prev) =>
                                prev.some((p) => p.disease.code === disease.code)
                                    ? prev
                                    : [...prev, { disease, is_primary: prev.length === 0 }],
                            )
                        }
                    />

                    {picked.length > 0 && (
                        <ul className="mt-2 divide-y divide-border rounded-md border border-border">
                            {picked.map((d) => (
                                <li
                                    key={d.disease.code}
                                    className="flex items-center gap-3 px-3 py-2"
                                >
                                    <span className="min-w-0 flex-1 truncate text-sm">
                                        {d.disease.name_ko}
                                        <span className="ml-2 font-mono text-xs text-ink-faint">
                                            {d.disease.code}
                                        </span>
                                    </span>

                                    <button
                                        type="button"
                                        onClick={() => setPrimary(d.disease.code)}
                                        className={cn(
                                            'shrink-0 rounded border px-2 py-0.5 text-xs transition-colors',
                                            d.is_primary
                                                ? 'border-brand bg-brand-soft text-brand'
                                                : 'border-border text-ink-faint hover:text-ink',
                                        )}
                                    >
                                        주진단
                                    </button>

                                    <button
                                        type="button"
                                        onClick={() =>
                                            setPicked((prev) =>
                                                prev.filter(
                                                    (p) => p.disease.code !== d.disease.code,
                                                ),
                                            )
                                        }
                                        aria-label={`${d.disease.name_ko} 빼기`}
                                        className={`shrink-0 ${ICON_BUTTON}`}
                                    >
                                        <X size={14} />
                                    </button>
                                </li>
                            ))}
                        </ul>
                    )}
                </div>

                <button
                    type="button"
                    onClick={() => save.mutate()}
                    disabled={!note.trim() || save.isPending}
                    className={BUTTON_PRIMARY}
                >
                    저장하고 처방으로
                </button>
            </div>
        </section>
    );
}

function VisitHistory({ patientId } : { patientId : string }) {
    const visits = useQuery({
        queryKey: qk.visits(patientId),
        queryFn: () => getVisits(patientId),
    });

    return (
        <section>
            <h2 className="mb-3 text-base font-medium">지난 진료</h2>

            {visits.isPending ? (
                <Pending />
            ) : visits.isError ? (
                <Failed error={visits.error} onRetry={() => void visits.refetch()} />
            ) : visits.data.length === 0 ? (
                <Empty label="지난 진료 기록이 없습니다" />
            ) : (
                <div className="divide-y divide-border border-y border-border">
                    {visits.data.map((visit) => (
                        <div key={visit.id} className="py-4">
                            <div className="flex items-baseline justify-between gap-3">
                                {/* 환자 앱 진료 상세와 같은 줄 구성 */}
                                <span className="min-w-0 truncate text-sm text-ink-muted">
                                    {formatShort(visit.visited_at)}
                                    {visit.department_name && ` · ${visit.department_name}`}
                                    {visit.staff_name && ` · ${visit.staff_name}`}
                                </span>
                                <Link
                                    to={`/prescriptions?visit=${visit.id}`}
                                    className="text-sm text-ink-muted transition-colors hover:text-ink"
                                >
                                    처방 등록
                                </Link>
                            </div>

                            {visit.note && (
                                <p className="mt-1.5 whitespace-pre-wrap text-sm leading-relaxed">
                                    {visit.note}
                                </p>
                            )}

                            {visit.diagnoses.length > 0 && (
                                <p className="mt-2 flex flex-wrap gap-1.5">
                                    {visit.diagnoses.map((d) => (
                                        <span
                                            key={d.id}
                                            className="rounded border border-border px-1.5 py-0.5 text-xs text-ink-muted"
                                        >
                                            {d.disease.name_ko}
                                            {d.is_primary && ' · 주진단'}
                                        </span>
                                    ))}
                                </p>
                            )}
                        </div>
                    ))}
                </div>
            )}
        </section>
    );
}
