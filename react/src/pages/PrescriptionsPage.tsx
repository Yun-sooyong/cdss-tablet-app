// 처방 >> 진료 기록에 약을 붙인다. 저장하면 서버가 복약 스케줄까지 만든다
import { useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { X } from 'lucide-react';
import { toast } from 'sonner';

import { createPrescription, getPrescriptions, searchDrugs } from '@/api';
import { qk } from '@/api/keys';
import type { Drug } from '@/api/types';
import { CodeSearchField } from '@/components/CodeSearchField';
import { BUTTON_PRIMARY, FIELD_INPUT, ICON_BUTTON } from '@/components/form';
import { Empty, Failed, Pending } from '@/components/QueryState';
import { formatShort } from '@/lib/format';

interface Line {
    drug : Drug;
    dose_per_take : string;
    times_per_day : string;
    total_days : string;
}

const NUMBER_FIELD = `${FIELD_INPUT} h-9 w-20 px-2 text-right`;

export default function PrescriptionsPage() {
    const [searchParams] = useSearchParams();
    const queryClient = useQueryClient();

    const visitId = searchParams.get('visit') ?? '';
    const [lines, setLines] = useState<Line[]>([]);

    const save = useMutation({
        mutationFn: () =>
            createPrescription({
                visit: visitId,
                drugs: lines.map((l) => ({
                    drug: l.drug.code,
                    dose_per_take: Number(l.dose_per_take),
                    times_per_day: Number(l.times_per_day),
                    total_days: Number(l.total_days),
                })),
            }),
        onSuccess: () => {
            void queryClient.invalidateQueries({ queryKey: qk.prescriptions(visitId) });
            setLines([]);
            toast.success('처방을 등록했습니다', {
                description: '환자 앱 복약 일정에 반영됩니다',
            });
        },
        onError: (error : Error) =>
            toast.error('등록하지 못했습니다', { description: error.message }),
    });

    // 셋 다 1 이상이어야 복약 스케줄이 만들어진다
    const filled = (l : Line) =>
        Number(l.dose_per_take) > 0 &&
        Number(l.times_per_day) >= 1 &&
        Number(l.total_days) >= 1;

    const canSave = lines.length > 0 && lines.every(filled);

    function patch(code : string, next : Partial<Line>) {
        setLines((prev) =>
            prev.map((l) => (l.drug.code === code ? { ...l, ...next } : l)),
        );
    }

    if (!visitId) {
        return (
            <div className="max-w-3xl">
                <Empty label="처방할 진료 기록을 먼저 골라 주세요" />
                <p className="mt-3 text-center text-sm text-ink-muted">
                    <Link to="/visits" className="underline-offset-2 hover:underline">
                        진료 기록으로 가기
                    </Link>
                </p>
            </div>
        );
    }

    return (
        <div className="max-w-3xl">
            <div className="mb-6 flex items-center justify-between gap-3 rounded-lg border border-border px-4 py-3 text-sm text-ink-muted">
                <span>
                    진료 기록{' '}
                    <span className="font-mono text-ink">{visitId.slice(0, 8)}</span>에
                    처방을 붙입니다
                </span>
                <Link to="/visits" className="shrink-0 transition-colors hover:text-ink">
                    진료 기록으로
                </Link>
            </div>

            <section className="mb-10 space-y-4 rounded-lg border border-border p-4">
                <CodeSearchField
                    label="약품"
                    placeholder="제품명 · 성분 · 코드"
                    queryKey={qk.drugSearch}
                    search={searchDrugs}
                    codeOf={(d) => d.code}
                    labelOf={(d) => d.product_name}
                    hintOf={(d) => d.ingredient}
                    onPick={(drug) =>
                        setLines((prev) =>
                            prev.some((l) => l.drug.code === drug.code)
                                ? prev
                                : [
                                      ...prev,
                                      {
                                          drug,
                                          dose_per_take: '1',
                                          times_per_day: '3',
                                          total_days: '3',
                                      },
                                  ],
                        )
                    }
                />

                {lines.length === 0 ? (
                    <p className="py-6 text-center text-sm text-ink-faint">
                        처방할 약을 검색해 추가하세요
                    </p>
                ) : (
                    <ul className="divide-y divide-border rounded-md border border-border">
                        {lines.map((l) => (
                            <li key={l.drug.code} className="px-3 py-3">
                                <div className="flex items-baseline gap-2">
                                    <span className="min-w-0 flex-1 truncate text-sm">
                                        {l.drug.product_name}
                                        {l.drug.ingredient && (
                                            <span className="ml-2 text-xs text-ink-faint">
                                                {l.drug.ingredient}
                                            </span>
                                        )}
                                    </span>
                                    <button
                                        type="button"
                                        onClick={() =>
                                            setLines((prev) =>
                                                prev.filter(
                                                    (p) => p.drug.code !== l.drug.code,
                                                ),
                                            )
                                        }
                                        aria-label={`${l.drug.product_name} 빼기`}
                                        className={ICON_BUTTON}
                                    >
                                        <X size={14} />
                                    </button>
                                </div>

                                {/* 환자 앱이 "1회 N단위 · 1일 N회 · N일분"으로 읽는 값 */}
                                <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-2 text-xs text-ink-muted">
                                    <label className="flex items-center gap-1.5">
                                        1회
                                        <input
                                            type="number"
                                            min="0"
                                            step="0.5"
                                            value={l.dose_per_take}
                                            onChange={(e) =>
                                                patch(l.drug.code, {
                                                    dose_per_take: e.target.value,
                                                })
                                            }
                                            className={NUMBER_FIELD}
                                        />
                                        {l.drug.unit}
                                    </label>

                                    <label className="flex items-center gap-1.5">
                                        하루
                                        <input
                                            type="number"
                                            min="1"
                                            value={l.times_per_day}
                                            onChange={(e) =>
                                                patch(l.drug.code, {
                                                    times_per_day: e.target.value,
                                                })
                                            }
                                            className={NUMBER_FIELD}
                                        />
                                        회
                                    </label>

                                    <label className="flex items-center gap-1.5">
                                        총
                                        <input
                                            type="number"
                                            min="1"
                                            value={l.total_days}
                                            onChange={(e) =>
                                                patch(l.drug.code, {
                                                    total_days: e.target.value,
                                                })
                                            }
                                            className={NUMBER_FIELD}
                                        />
                                        일
                                    </label>
                                </div>
                            </li>
                        ))}
                    </ul>
                )}

                <button
                    type="button"
                    onClick={() => save.mutate()}
                    disabled={!canSave || save.isPending}
                    className={BUTTON_PRIMARY}
                >
                    처방 등록
                </button>
            </section>

            <IssuedList visitId={visitId} />
        </div>
    );
}

function IssuedList({ visitId } : { visitId : string }) {
    const issued = useQuery({
        queryKey: qk.prescriptions(visitId),
        queryFn: () => getPrescriptions({ visit: visitId }),
    });

    return (
        <section>
            <h2 className="mb-3 text-base font-medium">이 진료의 처방</h2>

            {issued.isPending ? (
                <Pending />
            ) : issued.isError ? (
                <Failed error={issued.error} onRetry={() => void issued.refetch()} />
            ) : issued.data.length === 0 ? (
                <Empty label="등록된 처방이 없습니다" />
            ) : (
                <div className="divide-y divide-border border-y border-border">
                    {issued.data.map((p) => (
                        <div key={p.id} className="py-4">
                            <p className="text-sm text-ink-muted">
                                {formatShort(p.prescribed_at)}
                            </p>

                            <ul className="mt-1.5 space-y-1">
                                {p.drugs.map((d) => (
                                    <li key={d.id} className="text-sm">
                                        {d.drug.product_name}
                                        <span className="ml-2 text-xs text-ink-muted">
                                            1회 {d.dose_per_take}
                                            {d.drug.unit} · 1일 {d.times_per_day}회 ·{' '}
                                            {d.total_days}일분
                                        </span>
                                    </li>
                                ))}
                            </ul>
                        </div>
                    ))}
                </div>
            )}
        </section>
    );
}
