// 분석 등록 >> 환자 · 슬라이드 · 모델
import { useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Search, UploadCloud, X } from 'lucide-react';
import { toast } from 'sonner';

import {
    createBatch,
    getActiveModelVersions,
    requestUploadUrl,
    searchPatients,
} from '@/api';
import { qk } from '@/api/keys';
import { FIELD_INPUT, FIELD_SUBMIT, ICON_BUTTON } from '@/components/form';
import type { PatientSummary } from '@/api/types';
import { useUploads } from '@/components/upload/context';
import { patientBrief, patientFull } from '@/lib/patient';
import { cn } from '@/lib/utils';

const formatSize = (bytes : number) : string => {
    if (bytes >= 1024 ** 3) return `${(bytes / 1024 ** 3).toFixed(1)} GB`;
    return `${(bytes / 1024 ** 2).toFixed(1)} MB`;
};

export default function UploadPage() {
    const navigate = useNavigate();
    const queryClient = useQueryClient();
    const { enqueue } = useUploads();

    const { data: models } = useQuery({
        queryKey: qk.modelVersions,
        queryFn: getActiveModelVersions,
    });

    const [query, setQuery] = useState('');
    const [patient, setPatient] = useState<PatientSummary | null>(null);
    const [files, setFiles] = useState<File[]>([]);
    // '' >> 미선택. 목록이 오면 첫 번째가 기본
    const [modelId, setModelId] = useState('');
    const [dragOver, setDragOver] = useState(false);
    const inputRef = useRef<HTMLInputElement>(null);

    const chartNumber = query.trim();
    const search = useQuery({
        queryKey: qk.patientSearch(chartNumber),
        queryFn: () => searchPatients({ chartNumber }),
        enabled: !!chartNumber,
    });

    const totalSize = files.reduce((sum, f) => sum + f.size, 0);

    const pickedModel = modelId || models?.[0]?.id || '';
    // 모델이 없으면 분석을 걸 수 없다
    const canStart = !!patient && files.length > 0 && !!pickedModel;

    function addFiles(list : FileList | null) {
        if (!list) return;
        const incoming = Array.from(list);
        setFiles((prev) => {
            const names = new Set(prev.map((f) => f.name));
            return [...prev, ...incoming.filter((f) => !names.has(f.name))];
        });
    }

    // 배치 생성 → 파일별 서명 URL → 업로드 큐
    const start = useMutation({
        mutationFn: async () => {
            const batch = await createBatch(patient!.id);

            const queued = await Promise.all(
                files.map(async (file) => {
                    const image = await requestUploadUrl(batch.id, file.name);
                    return { file, uploadUrl: image.upload_url, filename: file.name };
                }),
            );

            return { batch, queued, count: files.length, name: patient!.name };
        },
        onSuccess: ({ batch, queued, count, name }) => {
            enqueue(batch.id, pickedModel || undefined, queued);
            void queryClient.invalidateQueries({ queryKey: qk.batches });

            toast('업로드를 시작했습니다', {
                description: `${name} · 슬라이드 ${count}장 · 헤더에서 진행 상황을 볼 수 있습니다`,
                action: {
                    label: '진행 보기',
                    onClick: () => navigate(`/batches/${batch.id}`),
                },
            });

            // 폼만 비우고 화면은 유지
            setPatient(null);
            setQuery('');
            setFiles([]);
        },
        onError: (error : Error) =>
            toast('업로드를 시작하지 못했습니다', { description: error.message }),
    });

    return (
        <div className="mx-auto max-w-5xl">
            <div className="grid gap-6 lg:grid-cols-[minmax(0,3fr)_minmax(0,2fr)] lg:items-start">
                <div>
                    <Section step={1} title="환자" done={!!patient}>
                        {patient ? (
                            <div className="flex items-center justify-between gap-4 rounded-md border border-border bg-brand-soft/40 px-4 py-3">
                                <span className="text-[15px]">{patientFull(patient)}</span>
                                <button
                                    type="button"
                                    onClick={() => setPatient(null)}
                                    className={`shrink-0 text-sm ${ICON_BUTTON}`}
                                >
                                    변경
                                </button>
                            </div>
                        ) : (
                            <>
                                <div className="relative">
                                    <Search
                                        size={15}
                                        className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-ink-faint"
                                    />
                                    <input
                                        value={query}
                                        onChange={(e) => setQuery(e.target.value)}
                                        placeholder="차트번호"
                                        aria-label="차트번호로 환자 검색"
                                        className={`${FIELD_INPUT} pl-9`}
                                    />
                                </div>
                                {query.trim() && (
                                    <div className="mt-3 divide-y divide-border rounded-md border border-border">
                                        {search.isError ? (
                                            <p
                                                role="alert"
                                                className="px-4 py-6 text-center text-sm text-danger"
                                            >
                                                검색하지 못했습니다.
                                            </p>
                                        ) : search.isPending ? (
                                            <p className="px-4 py-6 text-center text-sm text-ink-faint">
                                                검색 중
                                            </p>
                                        ) : search.data.length === 0 ? (
                                            <p className="px-4 py-6 text-center text-sm text-ink-faint">
                                                일치하는 환자가 없습니다
                                            </p>
                                        ) : (
                                            search.data.map((p) => (
                                                <button
                                                    key={p.id}
                                                    type="button"
                                                    onClick={() => setPatient(p)}
                                                    className="block w-full px-4 py-3 text-left text-[15px] transition-colors hover:bg-brand-soft/50"
                                                >
                                                    {patientFull(p)}
                                                </button>
                                            ))
                                        )}
                                    </div>
                                )}
                            </>
                        )}
                    </Section>

                    <Section step={2} title="슬라이드" disabled={!patient} done={files.length > 0}>
                        <div
                            onDragOver={(e) => {
                                e.preventDefault();
                                setDragOver(true);
                            }}
                            onDragLeave={() => setDragOver(false)}
                            onDrop={(e) => {
                                e.preventDefault();
                                setDragOver(false);
                                addFiles(e.dataTransfer.files);
                            }}
                            onClick={() => inputRef.current?.click()}
                            className={cn(
                                'cursor-pointer rounded-md border-2 border-dashed border-border px-6 py-10 text-center transition-colors',
                                dragOver && 'border-brand bg-brand-soft/40',
                            )}
                        >
                            <UploadCloud size={28} className="mx-auto mb-2 text-ink-faint" />
                            <p className="text-[15px]">파일을 끌어다 놓거나 클릭해서 선택</p>
                            <p className="mt-1 text-xs text-ink-faint">PNG · JPG · TIFF</p>

                            <input
                                ref={inputRef}
                                type="file"
                                multiple
                                accept=".png,.jpg,.jpeg,.tif,.tiff"
                                onChange={(e) => {
                                    addFiles(e.target.files);
                                    e.target.value = '';
                                }}
                                className="hidden"
                            />
                        </div>

                        {files.length > 0 && (
                            <div className="mt-3 divide-y divide-border rounded-md border border-border">
                                {files.map((f) => (
                                    <div key={f.name} className="flex items-center gap-3 px-4 py-2.5">
                                        <span
                                            className="min-w-0 flex-1 truncate text-sm"
                                            title={f.name}
                                        >
                                            {f.name}
                                        </span>
                                        <span className="shrink-0 font-mono text-xs tabular-nums text-ink-muted">
                                            {formatSize(f.size)}
                                        </span>
                                        <button
                                            type="button"
                                            onClick={(e) => {
                                                e.stopPropagation();
                                                setFiles((prev) =>
                                                    prev.filter((x) => x.name !== f.name),
                                                );
                                            }}
                                            aria-label={`${f.name} 제거`}
                                            className="shrink-0 text-ink-faint transition-colors hover:text-danger"
                                        >
                                            <X size={15} />
                                        </button>
                                    </div>
                                ))}
                            </div>
                        )}
                    </Section>
                </div>

                <div className="lg:sticky lg:top-6">
                    <Section step={3} title="모델" disabled={!canStart}>
                        <select
                            value={pickedModel}
                            onChange={(e) => setModelId(e.target.value)}
                            aria-label="분석 모델"
                            className={FIELD_INPUT}
                        >
                            {(models ?? []).map((m) => (
                                <option key={m.id} value={m.id}>
                                    {m.name} ({m.version})
                                </option>
                            ))}
                        </select>

                        <dl className="mt-5 space-y-2 border-t border-border pt-5 text-sm">
                            <SummaryRow
                                label="환자"
                                value={patient ? patientBrief(patient) : '-'}
                            />
                            <SummaryRow label="슬라이드" value={`${files.length}장`} />
                            <SummaryRow label="용량" value={formatSize(totalSize)} />
                        </dl>

                        <button
                            type="button"
                            onClick={() => start.mutate()}
                            disabled={!canStart || start.isPending}
                            className={`mt-5 ${FIELD_SUBMIT}`}
                        >
                            분석 시작
                        </button>

                        <p className="mt-2 text-center text-xs text-ink-faint">
                            업로드 중 창을 닫으면 중단됩니다
                        </p>
                    </Section>
                </div>
            </div>
        </div>
    );
}

function SummaryRow({ label, value } : { label : string; value : string }) {
    return (
        <div className="flex items-baseline justify-between gap-3">
            <dt className="shrink-0 text-ink-muted">{label}</dt>
            <dd className="min-w-0 truncate text-right" title={value}>
                {value}
            </dd>
        </div>
    );
}

function Section({
    step,
    title,
    disabled,
    done,
    children,
} : {
    step : number;
    title : string;
    disabled? : boolean;
    done? : boolean;
    children : React.ReactNode;
}) {
    return (
        <section className={cn('mb-6 last:mb-0', disabled && 'pointer-events-none opacity-40')}>
            <h2 className="mb-3 flex items-center gap-2 text-base font-medium">
                <span
                    className={cn(
                        'flex size-6 items-center justify-center rounded-full text-xs',
                        done ? 'bg-brand text-on-brand' : 'bg-brand-soft text-ink-muted',
                    )}
                >
                    {step}
                </span>
                {title}
            </h2>
            <div className="rounded-lg border border-border p-4">{children}</div>
        </section>
    );
}